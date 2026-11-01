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
  Future<void> cambiarEstado(String examenId, {required bool publicado}) {
    return firestore.collection('examenes').doc(examenId).update({
      'estado': publicado ? 'publicado' : 'borrador',
    });
  }
}
