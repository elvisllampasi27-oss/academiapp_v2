import '../../features/academic/domain/entities/curriculo.dart';
import '../../features/academic/domain/entities/tema.dart';
import 'modelo_contenido.dart';

class ResumenContenido {
  final Curriculo curriculo;
  final Set<String> publicados;
  final Map<String, MaterialTema> material;

  const ResumenContenido({
    required this.curriculo,
    required this.publicados,
    required this.material,
  });
}

/// Material de los temas de una versión: video, separata, contenidos,
/// quizzes, material del tutor y publicación.
abstract class RepositorioContenidoAdmin {
  Future<ResumenContenido> resumen(String versionId);

  Future<String> materialTutor(String versionId, String temaId);

  Future<List<PreguntaPractica>> preguntas(
    String versionId,
    String temaId,
    NivelQuiz nivel,
  );

  Future<void> guardarTema({
    required String versionId,
    required Tema tema,
    required String titulo,
    required String? video,
    required String? separata,
    required List<String> contenidos,
    required String materialTutor,
  });

  Future<void> guardarQuiz({
    required String versionId,
    required Tema tema,
    required NivelQuiz nivel,
    required List<PreguntaPractica> preguntas,
    required bool publicar,
  });

  Future<void> cambiarPublicacion({
    required String versionId,
    required Tema tema,
    required bool publicar,
  });
}

/// Borradores de preguntas con IA a partir del material del tema.
abstract class GeneradorQuiz {
  Future<List<PreguntaPractica>> generar({
    required String versionId,
    required String temaId,
    required NivelQuiz nivel,
    required int cantidad,
  });
}
