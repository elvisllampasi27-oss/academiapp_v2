import '../../domain/errors/excepcion_autenticacion.dart';

/// Traduce los códigos de FirebaseAuthException al lenguaje del dominio.
/// Función pura: se prueba sin Firebase.
TipoErrorAutenticacion traducirCodigoFirebaseAuth(String codigo) {
  return switch (codigo) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'INVALID_LOGIN_CREDENTIALS' => TipoErrorAutenticacion.credencialesInvalidas,
    'invalid-email' => TipoErrorAutenticacion.correoInvalido,
    'email-already-in-use' => TipoErrorAutenticacion.correoEnUso,
    'weak-password' => TipoErrorAutenticacion.contrasenaDebil,
    'too-many-requests' => TipoErrorAutenticacion.demasiadosIntentos,
    'user-disabled' => TipoErrorAutenticacion.cuentaDeshabilitada,
    'network-request-failed' => TipoErrorAutenticacion.sinConexion,
    'operation-not-allowed' => TipoErrorAutenticacion.operacionNoPermitida,
    'account-exists-with-different-credential' =>
      TipoErrorAutenticacion.correoEnUso,
    'popup-closed-by-user' ||
    'cancelled-popup-request' ||
    'web-context-canceled' ||
    'canceled' => TipoErrorAutenticacion.cancelado,
    'popup-blocked' => TipoErrorAutenticacion.ventanaBloqueada,
    _ => TipoErrorAutenticacion.desconocido,
  };
}
