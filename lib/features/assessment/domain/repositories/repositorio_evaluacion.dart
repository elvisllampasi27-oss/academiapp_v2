import '../entities/evaluacion.dart';
import '../entities/pregunta_presentada.dart';

abstract class RepositorioEvaluacion {
  Future<List<Evaluacion>> obtenerPublicadasPorTema({
    required String temaId,
    required String versionId,
  });

  /// Preguntas activas, sin respuestas correctas.
  Future<List<PreguntaPresentada>> obtenerPreguntas(String evaluacionId);
}
