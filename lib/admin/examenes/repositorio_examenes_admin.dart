import 'modelo_examen_admin.dart';

abstract class RepositorioExamenesAdmin {
  Future<List<ExamenAdmin>> examenes();

  /// Todas las preguntas del examen (también las inactivas), con su clave.
  Future<List<PreguntaAdmin>> preguntas(String examenId);

  /// Guarda la pregunta y su clave, y mantiene al día los totales del
  /// examen. [todas] es la lista completa del
  /// examen ya con el cambio aplicado.
  Future<void> guardar(
    PreguntaAdmin pregunta, {
    PreguntaAdmin? anterior,
    required List<PreguntaAdmin> todas,
  });

  Future<void> cambiarEstado(String examenId, {required bool publicado});

  /// Borra la pregunta y su clave y actualiza los totales. [restantes] son las preguntas que quedan.
  Future<void> eliminarPregunta(
    PreguntaAdmin pregunta, {
    required List<PreguntaAdmin> restantes,
  });

  /// Borra el examen con todas sus preguntas y claves.
  Future<void> eliminarExamen(String examenId);

  /// Crea o reemplaza un examen completo desde JSON. Las preguntas que ya
  /// no vienen se desactivan (no se borran). Un examen nuevo queda en
  /// borrador hasta que lo publiques. [extra] va al documento del examen
  /// (versión y semana de un examen semanal).
  Future<void> importar({
    required String examenId,
    required String tipo,
    required String fecha,
    required String titulo,
    required List<PreguntaAdmin> preguntas,
    Map<String, Object?> extra = const {},
  });
}
