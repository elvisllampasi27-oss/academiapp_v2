import '../entities/correccion_intento.dart';

/// La corrección ocurre en el servidor (Cloud Functions).
abstract class ServicioCorreccionEvaluacion {
  Future<CorreccionIntento> enviar({
    required String evaluacionId,
    required Map<String, String> respuestas,
    required Map<String, int> tiemposMs,
  });
}
