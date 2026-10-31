import '../entities/progreso_clase.dart';

abstract class RepositorioProgresoClase {
  Future<ProgresoClase?> obtener({
    required String usuarioId,
    required String versionId,
    required String temaId,
  });

  Future<void> guardar({
    required String usuarioId,
    required ProgresoClase progreso,
  });
}
