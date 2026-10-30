import '../../domain/errors/excepcion_autenticacion.dart';

/// Convierte cualquier error del flujo de identidad en un mensaje seguro
/// para el estudiante (nunca muestra trazas ni mensajes internos).
String mensajeErrorAutenticacion(Object error) {
  if (error is ExcepcionAutenticacion) {
    return switch (error.tipo) {
      TipoErrorAutenticacion.credencialesInvalidas =>
        'Correo o contraseña incorrectos.',
      TipoErrorAutenticacion.correoInvalido =>
        'El correo no tiene un formato válido.',
      TipoErrorAutenticacion.correoEnUso =>
        'Ya existe una cuenta con ese correo.',
      TipoErrorAutenticacion.contrasenaDebil =>
        'La contraseña es demasiado débil.',
      TipoErrorAutenticacion.demasiadosIntentos =>
        'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
      TipoErrorAutenticacion.cuentaDeshabilitada =>
        'Esta cuenta ha sido deshabilitada.',
      TipoErrorAutenticacion.sinConexion =>
        'No hay conexión. Revisa tu internet.',
      TipoErrorAutenticacion.operacionNoPermitida =>
        'Este método de acceso no está habilitado.',
      TipoErrorAutenticacion.desconocido =>
        'Ocurrió un error inesperado. Inténtalo de nuevo.',
    };
  }

  // Los servicios de dominio usan StateError con mensajes ya pensados para
  // el estudiante (perfil inexistente, cuenta inactiva, rol no permitido).
  if (error is StateError) {
    return error.message;
  }

  return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
}
