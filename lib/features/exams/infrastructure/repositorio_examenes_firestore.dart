import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/examen.dart';
import '../domain/entities/simulacro.dart';
import '../domain/repositories/repositorio_examenes.dart';
import 'examenes_desde_mapa.dart';

class RepositorioExamenesFirestore implements RepositorioExamenes {
  final FirebaseFirestore firestore;

  RepositorioExamenesFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<ExamenPasado>> listar() async {
    final consulta = await firestore
        .collection('examenes')
        .where('estado', isEqualTo: 'publicado')
        .get();

    return [for (final d in consulta.docs) ?examenDesdeMapa(d.id, d.data())]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  @override
  Future<List<PreguntaExamen>> preguntas(String examenId) async {
    final consulta = await firestore
        .collection('preguntas_examen')
        .where('examenId', isEqualTo: examenId)
        .where('activa', isEqualTo: true)
        .get();

    return [for (final d in consulta.docs) preguntaDesdeMapa(d.id, d.data())]
      ..sort((a, b) => a.numero.compareTo(b.numero));
  }

  @override
  Future<List<NotaSemanal>> notasSemanales(String uid) async {
    // Las reglas solo dejan leer los suyos: se filtra por usuarioId.
    final consulta = await firestore
        .collection('simulacros')
        .where('usuarioId', isEqualTo: uid)
        .get();
    return [
      for (final d in consulta.docs)
        if (d.data() case {
          'estado': 'completado',
          'examenSemanalId': String _,
          'semana': final num semana,
          'puntaje': final num puntaje,
        })
          NotaSemanal(
            semana: semana.toInt(),
            puntaje: puntaje.toInt(),
            titulo: (d.data()['titulo'] as String?) ?? '',
          ),
    ]..sort((a, b) => a.semana.compareTo(b.semana));
  }
}
