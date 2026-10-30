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
    _ => TipoErrorAutenticacion.desconocido,
  };
}
