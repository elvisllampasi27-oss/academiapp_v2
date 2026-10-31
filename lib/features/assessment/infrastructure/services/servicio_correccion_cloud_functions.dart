import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/correccion_intento.dart';
import '../../domain/repositories/servicio_correccion_evaluacion.dart';
import 'correccion_desde_mapa.dart';

class ServicioCorreccionCloudFunctions implements ServicioCorreccionEvaluacion {
  final FirebaseFunctions functions;

  ServicioCorreccionCloudFunctions({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<CorreccionIntento> enviar({
    required String evaluacionId,
    required Map<String, String> respuestas,
    required Map<String, int> tiemposMs,
  }) async {
    try {
      final resultado = await functions
          .httpsCallable('enviarIntentoEvaluacion')
          .call<Map<Object?, Object?>>({
            'evaluacionId': evaluacionId,
            'respuestas': respuestas,
            'tiemposMs': tiemposMs,
          });

      return correccionDesdeMapa(resultado.data);
    } on FirebaseFunctionsException catch (error) {
      throw StateError(mensajeErrorCorreccion(error.code, error.message));
    }
  }
}

/// Los errores que la función lanza a propósito (permiso, no publicado...)
/// ya traen un mensaje para el estudiante. Los fallos inesperados del
/// servidor ("internal", "unavailable"...) no deben mostrarse en crudo.
String mensajeErrorCorreccion(String codigo, String? mensaje) {
  const codigosConMensajePropio = {
    'unauthenticated',
    'permission-denied',
    'not-found',
    'failed-precondition',
    'invalid-argument',
  };

  if (codigosConMensajePropio.contains(codigo) &&
      mensaje != null &&
      mensaje.isNotEmpty) {
    return mensaje;
  }

  if (codigo == 'unavailable' || codigo == 'deadline-exceeded') {
    return 'No hay conexión con el servidor. Inténtalo de nuevo.';
  }

  return 'Ocurrió un error al corregir la práctica. Inténtalo de nuevo.';
}
