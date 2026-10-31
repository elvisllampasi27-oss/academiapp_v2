import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/evaluacion.dart';
import '../../domain/entities/pregunta.dart';
import '../../domain/entities/pregunta_presentada.dart';
import '../../domain/repositories/repositorio_evaluacion.dart';

class RepositorioEvaluacionFirestore implements RepositorioEvaluacion {
  final FirebaseFirestore firestore;

  RepositorioEvaluacionFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Evaluacion>> obtenerPublicadasPorTema({
    required String temaId,
    required String versionId,
  }) async {
    final consulta = await firestore
        .collection('evaluaciones')
        .where('temaId', isEqualTo: temaId)
        .where('versionId', isEqualTo: versionId)
        .where('estado', isEqualTo: EstadoEvaluacion.publicada.name)
        .get();

    final evaluaciones = <Evaluacion>[];

    for (final documento in consulta.docs) {
      final datos = documento.data();
      final tipo = TipoEvaluacion.values.asNameMap()[datos['tipo']];
      final estado = EstadoEvaluacion.values.asNameMap()[datos['estado']];

      if (tipo == null || estado == null) continue;

      evaluaciones.add(
        Evaluacion(
          id: documento.id,
          temaId: datos['temaId'] as String,
          versionId: datos['versionId'] as String,
          tipo: tipo,
          estado: estado,
          nivel: datos['nivel'] as String?,
        ),
      );
    }

    return evaluaciones;
  }

  @override
  Future<List<PreguntaPresentada>> obtenerPreguntas(String evaluacionId) async {
    final consulta = await firestore
        .collection('preguntas')
        .where('evaluacionId', isEqualTo: evaluacionId)
        .where('activa', isEqualTo: true)
        .get();

    return consulta.docs.map((documento) {
      final datos = documento.data();
      final opciones = (datos['opciones'] as List).cast<Map<String, dynamic>>();

      return PreguntaPresentada(
        id: documento.id,
        evaluacionId: datos['evaluacionId'] as String,
        enunciado: datos['enunciado'] as String,
        dificultad:
            DificultadPregunta.values.asNameMap()[datos['dificultad']] ??
            DificultadPregunta.basica,
        orden: datos['orden'] as int,
        opciones: [
          for (final opcion in opciones)
            OpcionPresentada(
              id: opcion['id'] as String,
              texto: opcion['texto'] as String,
            ),
        ],
      );
    }).toList();
  }
}
