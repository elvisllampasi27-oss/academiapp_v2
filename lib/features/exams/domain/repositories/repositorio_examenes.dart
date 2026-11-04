import '../entities/examen.dart';
import '../entities/simulacro.dart';

abstract class RepositorioExamenes {
  /// Exámenes pasados publicados, del más reciente al más antiguo.
  Future<List<ExamenPasado>> listar();

  /// Preguntas activas de un examen, en su orden original.
  Future<List<PreguntaExamen>> preguntas(String examenId);

  /// Sus notas de los exámenes semanales, de la semana 1 en adelante.
  Future<List<NotaSemanal>> notasSemanales(String uid);
}
