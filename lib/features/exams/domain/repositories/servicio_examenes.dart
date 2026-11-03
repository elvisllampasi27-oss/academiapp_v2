import '../entities/examen.dart';
import '../entities/simulacro.dart';

/// Error con un mensaje listo para mostrar al estudiante.
class ErrorExamen implements Exception {
  final String mensaje;

  const ErrorExamen(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Operaciones que necesitan las claves: se hacen en el servidor.
/// Todas lanzan [ErrorExamen] si fallan.
abstract class ServicioExamenes {
  Future<RevisionPregunta> revisar({
    required String preguntaId,
    required String opcionId,
  });

  Future<Simulacro> iniciarSimulacro();

  Future<ResultadoSimulacro> enviarSimulacro({
    required String simulacroId,
    required Map<String, String> respuestas,
  });

  /// Qué examen semanal le toca ahora y si ya lo dio.
  Future<EstadoExamenSemanal> estadoSemanal();

  /// Ranking del último examen semanal que dio (null si aún no da ninguno).
  Future<RankingSemanal?> ranking();
}
