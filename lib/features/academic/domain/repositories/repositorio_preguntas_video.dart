import '../entities/pregunta_video.dart';

/// Preguntas dentro de la clase de un tema (una lista por versión y tema).
abstract class RepositorioPreguntasVideo {
  /// Ordenadas por segundo. Vacía si el tema no tiene.
  Future<List<PreguntaVideo>> delTema({
    required String versionId,
    required String temaId,
  });

  /// Reemplaza todas las del tema (solo el administrador).
  Future<void> guardar({
    required String versionId,
    required String temaId,
    required List<PreguntaVideo> preguntas,
  });
}
