import '../entities/mensaje_tutor.dart';
import '../entities/respuesta_tutor.dart';

/// Tutor de dudas de un tema. La respuesta se genera en el servidor: las
/// claves del proveedor de IA nunca están en el celular.
abstract class ServicioTutor {
  /// Lanza [ErrorTutor] si no se pudo responder.
  Future<RespuestaTutor> preguntar({
    required String versionId,
    required String temaId,
    required String pregunta,
    required List<MensajeTutor> historial,
  });
}
