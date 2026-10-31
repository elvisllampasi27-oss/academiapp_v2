import '../entities/recurso.dart';

abstract class RepositorioRecurso {
  /// Recursos activos de un tema para una versión académica concreta:
  /// el estudiante solo ve el material de la versión en la que está.
  Future<List<Recurso>> obtenerActivosPorTema({
    required String temaId,
    required String versionId,
  });
}
