import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'modelo_examen_admin.dart';
import 'repositorio_examenes_admin.dart';

class RepositorioExamenesAdminFirestore implements RepositorioExamenesAdmin {
  final FirebaseFirestore firestore;

  RepositorioExamenesAdminFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<ExamenAdmin>> examenes() async {
    final consulta = await firestore.collection('examenes').get();

    return [
      for (final d in consulta.docs)
        ExamenAdmin(
          id: d.id,
          titulo: d.data()['titulo'] as String? ?? d.id,
          tipo: d.data()['tipo'] as String? ?? '',
          fecha: d.data()['fecha'] as String? ?? '',
          estado: d.data()['estado'] as String? ?? 'borrador',
          totalPreguntas: (d.data()['totalPreguntas'] as num?)?.toInt() ?? 0,
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  @override
  Future<List<PreguntaAdmin>> preguntas(String examenId) async {
    final resultados = await Future.wait([
      firestore
          .collection('preguntas_examen')
          .where('examenId', isEqualTo: examenId)
          .get(),
      firestore
          .collection('claves_examen')
          .where('examenId', isEqualTo: examenId)
          .get(),
    ]);
    final claves = {for (final d in resultados[1].docs) d.id: d.data()};

    return [
      for (final d in resultados[0].docs)
        preguntaAdminDesdeMapas(d.id, d.data(), claves[d.id]),
    ]..sort((a, b) => a.numero.compareTo(b.numero));
  }

  @override
  Future<void> guardar(
    PreguntaAdmin pregunta, {
    PreguntaAdmin? anterior,
    required List<PreguntaAdmin> todas,
  }) async {
    final lote = firestore.batch();
    final indice = firestore.collection('indices').doc('preguntas_examen');

    lote.set(
      firestore.collection('preguntas_examen').doc(pregunta.id),
      pregunta.datosPregunta(),
    );
    lote.set(
      firestore.collection('claves_examen').doc(pregunta.id),
      pregunta.datosClave(),
    );

    // Índice del examen tipo admisión: se quita la entrada vieja y se pone
    // la nueva (si la pregunta está activa).
    if (anterior != null && anterior.activa) {
      lote.set(indice, {
        'preguntas': FieldValue.arrayRemove([
          {'id': anterior.id, 'seccion': anterior.seccion},
        ]),
      }, SetOptions(merge: true));
    }
    if (pregunta.activa) {
      lote.set(indice, {
        'preguntas': FieldValue.arrayUnion([
          {'id': pregunta.id, 'seccion': pregunta.seccion.trim()},
        ]),
      }, SetOptions(merge: true));
    }

    lote.update(firestore.collection('examenes').doc(pregunta.examenId), {
      'totalPreguntas': todas.where((p) => p.activa).length,
      'secciones': seccionesDe(todas),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    await lote.commit();
  }

  @override
  Future<void> importar({
    required String examenId,
    required String tipo,
    required String fecha,
    required String titulo,
    required List<PreguntaAdmin> preguntas,
  }) async {
    final (anteriores, examen) = await (
      this.preguntas(examenId),
      firestore.collection('examenes').doc(examenId).get(),
    ).wait;
    final nuevas = {for (final p in preguntas) p.id};
    final indice = firestore.collection('indices').doc('preguntas_examen');

    // Firestore admite 500 escrituras por lote: se arman en grupos.
    final operaciones = <void Function(WriteBatch)>[
      for (final p in anteriores)
        if (!nuevas.contains(p.id) && p.activa)
          (l) => l.update(firestore.collection('preguntas_examen').doc(p.id), {
            'activa': false,
          }),
      for (final p in preguntas) ...[
        (l) => l.set(
          firestore.collection('preguntas_examen').doc(p.id),
          p.datosPregunta(),
        ),
        (l) => l.set(
          firestore.collection('claves_examen').doc(p.id),
          p.datosClave(),
        ),
      ],
    ];
    for (var i = 0; i < operaciones.length; i += 450) {
      final lote = firestore.batch();
      for (final op in operaciones.skip(i).take(450)) {
        op(lote);
      }
      await lote.commit();
    }

    // Índice del examen tipo admisión y datos del examen, al final.
    final lote = firestore.batch();
    if (anteriores.any((p) => p.activa)) {
      lote.set(indice, {
        'preguntas': FieldValue.arrayRemove([
          for (final p in anteriores)
            if (p.activa) {'id': p.id, 'seccion': p.seccion},
        ]),
      }, SetOptions(merge: true));
    }
    final todas = {
      for (final p in anteriores) p.id: p.copiar(activa: false),
      for (final p in preguntas) p.id: p,
    }.values;
    lote.set(firestore.collection('examenes').doc(examenId), {
      'tipo': tipo,
      'fecha': fecha,
      'titulo': titulo,
      'totalPreguntas': todas.where((p) => p.activa).length,
      'secciones': seccionesDe(todas),
      'estado': examen.data()?['estado'] ?? 'borrador',
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await lote.commit();

    // El arrayUnion va en otro lote: en el mismo, chocaría con el arrayRemove.
    await indice.set({
      'preguntas': FieldValue.arrayUnion([
        for (final p in preguntas)
          if (p.activa) {'id': p.id, 'seccion': p.seccion.trim()},
      ]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> cambiarEstado(String examenId, {required bool publicado}) {
    return firestore.collection('examenes').doc(examenId).update({
      'estado': publicado ? 'publicado' : 'borrador',
    });
  }
}
