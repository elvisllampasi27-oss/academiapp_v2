import '../entities/correccion_intento.dart';

/// La corrección ocurre en el servidor (Cloud Functions).
abstract class ServicioCorreccionEvaluacion {
  /// [intentoId] lo genera la app al empezar el intento: si el envío se
  /// repite (mala conexión, doble toque), el servidor no crea otro intento.
  Future<CorreccionIntento> enviar({
    required String intentoId,
    required String evaluacionId,
    required Map<String, String> respuestas,
    required Map<String, int> tiemposMs,
  });
}
