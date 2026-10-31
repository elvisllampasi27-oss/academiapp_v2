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
      // Los mensajes del servidor ya están escritos para el estudiante.
      throw StateError(error.message ?? 'No se pudo corregir la práctica.');
    }
  }
}
