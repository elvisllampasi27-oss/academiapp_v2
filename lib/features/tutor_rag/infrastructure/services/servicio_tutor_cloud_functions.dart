import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/mensaje_tutor.dart';
import '../../domain/entities/respuesta_tutor.dart';
import '../../domain/exceptions/error_tutor.dart';
import '../../domain/repositories/servicio_tutor.dart';

class ServicioTutorCloudFunctions implements ServicioTutor {
  final FirebaseFunctions functions;

  ServicioTutorCloudFunctions({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<RespuestaTutor> preguntar({
    required String versionId,
    required String temaId,
    required String pregunta,
    required List<MensajeTutor> historial,
  }) async {
    try {
      final resultado = await functions
          .httpsCallable('preguntarTutor')
          .call<Map<Object?, Object?>>({
            'versionId': versionId,
            'temaId': temaId,
            'pregunta': pregunta,
            'historial': [
              for (final mensaje in historial)
                {
                  'rol': mensaje.autor == AutorMensaje.estudiante
                      ? 'estudiante'
                      : 'tutor',
                  'texto': mensaje.texto,
                },
            ],
          });

      return respuestaDesdeMapa(resultado.data);
    } on FirebaseFunctionsException catch (error) {
      throw ErrorTutor(mensajeErrorTutor(error.code, error.message));
    }
  }
}

RespuestaTutor respuestaDesdeMapa(Map<Object?, Object?> datos) {
  final texto = datos['respuesta'];

  if (texto is! String || texto.trim().isEmpty) {
    throw const ErrorTutor('El tutor no pudo responder. Inténtalo de nuevo.');
  }

  return RespuestaTutor(
    texto: texto.trim(),
    restantesHoy: (datos['restantesHoy'] as num?)?.toInt(),
    limiteDiario: (datos['limiteDiario'] as num?)?.toInt(),
  );
}

/// Los errores lanzados a propósito por la función traen un mensaje para el
/// estudiante; los inesperados no se muestran en crudo.
String mensajeErrorTutor(String codigo, String? mensaje) {
  const codigosConMensajePropio = {
    'unauthenticated',
    'permission-denied',
    'failed-precondition',
    'invalid-argument',
    'resource-exhausted',
  };

  if (codigosConMensajePropio.contains(codigo) &&
      mensaje != null &&
      mensaje.isNotEmpty) {
    return mensaje;
  }

  if (codigo == 'unavailable' || codigo == 'deadline-exceeded') {
    return 'No hay conexión con el tutor. Inténtalo de nuevo.';
  }

  return 'El tutor no pudo responder. Inténtalo de nuevo.';
}
