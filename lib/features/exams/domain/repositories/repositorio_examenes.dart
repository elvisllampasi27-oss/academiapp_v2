import '../entities/examen.dart';

abstract class RepositorioExamenes {
  /// Exámenes pasados publicados, del más reciente al más antiguo.
  Future<List<ExamenPasado>> listar();

  /// Preguntas activas de un examen, en su orden original.
  Future<List<PreguntaExamen>> preguntas(String examenId);
}
