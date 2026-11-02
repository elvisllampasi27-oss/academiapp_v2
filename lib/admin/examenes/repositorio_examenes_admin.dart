import 'modelo_examen_admin.dart';

abstract class RepositorioExamenesAdmin {
  Future<List<ExamenAdmin>> examenes();

  /// Todas las preguntas del examen (también las inactivas), con su clave.
  Future<List<PreguntaAdmin>> preguntas(String examenId);

  /// Guarda la pregunta y su clave, y mantiene al día el examen (totales)
  /// y el índice del examen tipo admisión. [todas] es la lista completa del
  /// examen ya con el cambio aplicado.
  Future<void> guardar(
    PreguntaAdmin pregunta, {
    PreguntaAdmin? anterior,
    required List<PreguntaAdmin> todas,
  });

  Future<void> cambiarEstado(String examenId, {required bool publicado});

  /// Crea o reemplaza un examen completo desde JSON. Las preguntas que ya
  /// no vienen se desactivan (no se borran). Un examen nuevo queda en
  /// borrador hasta que lo publiques.
  Future<void> importar({
    required String examenId,
    required String tipo,
    required String fecha,
    required String titulo,
    required List<PreguntaAdmin> preguntas,
  });
}
