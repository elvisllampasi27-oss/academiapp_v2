import 'package:cloud_functions/cloud_functions.dart';

import '../domain/entities/examen.dart';
import '../domain/entities/simulacro.dart';
import '../domain/repositories/servicio_examenes.dart';
import 'examenes_desde_mapa.dart';

class ServicioExamenesCloudFunctions implements ServicioExamenes {
  final FirebaseFunctions functions;

  ServicioExamenesCloudFunctions({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  Future<Map<Object?, Object?>> _llamar(
    String nombre, [
    Map<String, Object?> datos = const {},
  ]) async {
    try {
      final r = await functions
          .httpsCallable(nombre)
          .call<Map<Object?, Object?>>(datos);
      return r.data;
    } on FirebaseFunctionsException catch (e) {
      throw ErrorExamen(mensajeErrorExamen(e.code, e.message));
    }
  }

  @override
  Future<RevisionPregunta> revisar({
    required String preguntaId,
    required String opcionId,
  }) async => revisionDesdeMapa(
    await _llamar('revisarPreguntaExamen', {
      'preguntaId': preguntaId,
      'opcionId': opcionId,
    }),
  );

  @override
  Future<Simulacro> iniciarSimulacro() async =>
      simulacroDesdeMapa(await _llamar('iniciarSimulacro'));

  @override
  Future<ResultadoSimulacro> enviarSimulacro({
    required String simulacroId,
    required Map<String, String> respuestas,
  }) async => resultadoDesdeMapa(
    await _llamar('enviarSimulacro', {
      'simulacroId': simulacroId,
      'respuestas': respuestas,
    }),
  );
}

/// Los errores lanzados a propósito traen un mensaje para el estudiante;
/// los inesperados no se muestran en crudo.
String mensajeErrorExamen(String codigo, String? mensaje) {
  const conMensajePropio = {
    'unauthenticated',
    'permission-denied',
    'not-found',
    'failed-precondition',
    'invalid-argument',
  };

  if (conMensajePropio.contains(codigo) &&
      mensaje != null &&
      mensaje.isNotEmpty) {
    return mensaje;
  }
  if (codigo == 'unavailable' || codigo == 'deadline-exceeded') {
    return 'No hay conexión con el servidor. Inténtalo de nuevo.';
  }
  return 'Ocurrió un error. Inténtalo de nuevo.';
}
