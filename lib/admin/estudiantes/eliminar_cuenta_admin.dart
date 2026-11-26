import 'package:cloud_functions/cloud_functions.dart';

/// Borra la cuenta de un alumno y sus datos (función eliminarCuentaAlumno),
/// para quien lo pidió por correo. Lanza [StateError] con un mensaje claro.
Future<void> eliminarCuentaAlumno(String uid) async {
  try {
    await FirebaseFunctions.instance
        .httpsCallable(
          'eliminarCuentaAlumno',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
        )
        .call<Object?>({'uid': uid});
  } on FirebaseFunctionsException catch (e) {
    throw StateError(
      e.code == 'not-found'
          ? 'La función todavía no está publicada (necesita el plan Blaze).'
          : e.message ?? 'No se pudo eliminar la cuenta.',
    );
  }
}
