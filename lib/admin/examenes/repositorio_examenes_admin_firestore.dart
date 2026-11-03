import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'modelo_examen_admin.dart';
import 'repositorio_examenes_admin.dart';

/// Dónde vive cada tipo de examen. Los pasados los lee el estudiante; los
/// semanales solo el administrador y Cloud Functions.
class ColeccionesExamen {
  final String examenes;
  final String preguntas;
  final String claves;

  const ColeccionesExamen(this.examenes, this.preguntas, this.claves);

  static const pasados = ColeccionesExamen(
    'examenes',
    'preguntas_examen',
    'claves_examen',
  );
  static const semanales = ColeccionesExamen(
    'examenes_semanales',
    'preguntas_semanales',
    'claves_semanales',
  );
}

class RepositorioExamenesAdminFirestore implements RepositorioExamenesAdmin {
  final FirebaseFirestore firestore;
  final ColeccionesExamen colecciones;

  RepositorioExamenesAdminFirestore({
    FirebaseFirestore? firestore,
    this.colecciones = ColeccionesExamen.pasados,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _examenes =>
      firestore.collection(colecciones.examenes);
  CollectionReference<Map<String, dynamic>> get _preguntas =>
      firestore.collection(colecciones.preguntas);
  CollectionReference<Map<String, dynamic>> get _claves =>
      firestore.collection(colecciones.claves);

  @override
  Future<List<ExamenAdmin>> examenes() async {
    final consulta = await _examenes.get();

    return [
      for (final d in consulta.docs)
        ExamenAdmin(
          id: d.id,
          titulo: d.data()['titulo'] as String? ?? d.id,
          tipo: d.data()['tipo'] as String? ?? '',
          fecha: d.data()['fecha'] as String? ?? '',
          estado: d.data()['estado'] as String? ?? 'borrador',
          totalPreguntas: (d.data()['totalPreguntas'] as num?)?.toInt() ?? 0,
          versionId: d.data()['versionId'] as String?,
          semana: (d.data()['semana'] as num?)?.toInt(),
        ),
    ]..sort((a, b) {
      // Semanales: por versión y semana; pasados: el más nuevo primero.
      if (a.semana != null && b.semana != null) {
        final v = (a.versionId ?? '').compareTo(b.versionId ?? '');
        return v != 0 ? v : a.semana!.compareTo(b.semana!);
      }
      return b.fecha.compareTo(a.fecha);
    });
  }

  @override
  Future<List<PreguntaAdmin>> preguntas(String examenId) async {
    final (preguntas, claves) = await (
      _preguntas.where('examenId', isEqualTo: examenId).get(),
      _claves.where('examenId', isEqualTo: examenId).get(),
    ).wait;
    final porId = {for (final d in claves.docs) d.id: d.data()};

    return [
      for (final d in preguntas.docs)
        preguntaAdminDesdeMapas(d.id, d.data(), porId[d.id]),
    ]..sort((a, b) => a.numero.compareTo(b.numero));
  }

  Map<String, Object?> _totales(Iterable<PreguntaAdmin> todas) => {
    'totalPreguntas': todas.where((p) => p.activa).length,
    'secciones': seccionesDe(todas),
    'actualizadoEn': FieldValue.serverTimestamp(),
  };

  @override
  Future<void> guardar(
    PreguntaAdmin pregunta, {
    PreguntaAdmin? anterior,
    required List<PreguntaAdmin> todas,
  }) async {
    final lote = firestore.batch()
      ..set(_preguntas.doc(pregunta.id), pregunta.datosPregunta())
      ..set(_claves.doc(pregunta.id), pregunta.datosClave())
      ..update(_examenes.doc(pregunta.examenId), _totales(todas));
    await lote.commit();
  }

  @override
  Future<void> importar({
    required String examenId,
    required String tipo,
    required String fecha,
    required String titulo,
    required List<PreguntaAdmin> preguntas,
    Map<String, Object?> extra = const {},
  }) async {
    final (anteriores, examen) = await (
      this.preguntas(examenId),
      _examenes.doc(examenId).get(),
    ).wait;
    final nuevas = {for (final p in preguntas) p.id};

    // Firestore admite 500 escrituras por lote: se arman en grupos.
    final operaciones = <void Function(WriteBatch)>[
      for (final p in anteriores)
        if (!nuevas.contains(p.id) && p.activa)
          (l) => l.update(_preguntas.doc(p.id), {'activa': false}),
      for (final p in preguntas) ...[
        (l) => l.set(_preguntas.doc(p.id), p.datosPregunta()),
        (l) => l.set(_claves.doc(p.id), p.datosClave()),
      ],
    ];
    await _enLotes(operaciones);

    final todas = {
      for (final p in anteriores) p.id: p.copiar(activa: false),
      for (final p in preguntas) p.id: p,
    }.values;
    await _examenes.doc(examenId).set({
      ...extra,
      'tipo': tipo,
      'fecha': fecha,
      'titulo': titulo,
      'estado': examen.data()?['estado'] ?? 'borrador',
      ..._totales(todas),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> eliminarPregunta(
    PreguntaAdmin pregunta, {
    required List<PreguntaAdmin> restantes,
  }) async {
    final lote = firestore.batch()
      ..delete(_preguntas.doc(pregunta.id))
      ..delete(_claves.doc(pregunta.id))
      ..update(_examenes.doc(pregunta.examenId), _totales(restantes));
    await lote.commit();
  }

  @override
  Future<void> eliminarExamen(String examenId) async {
    final preguntas = await this.preguntas(examenId);
    await _enLotes([
      for (final p in preguntas) ...[
        (l) => l.delete(_preguntas.doc(p.id)),
        (l) => l.delete(_claves.doc(p.id)),
      ],
    ]);
    // El examen al final: si algo falla a mitad, sigue en la lista y se
    // puede volver a eliminar.
    await _examenes.doc(examenId).delete();
  }

  @override
  Future<void> cambiarEstado(String examenId, {required bool publicado}) {
    return _examenes.doc(examenId).update({
      'estado': publicado ? 'publicado' : 'borrador',
    });
  }

  Future<void> _enLotes(List<void Function(WriteBatch)> operaciones) async {
    for (var i = 0; i < operaciones.length; i += 450) {
      final lote = firestore.batch();
      for (final op in operaciones.skip(i).take(450)) {
        op(lote);
      }
      await lote.commit();
    }
  }
}
