/// Reglas mínimas de formato para correo y contraseña.
/// Firebase vuelve a validar en el servidor; esto evita viajes inútiles
/// y permite mostrar mensajes claros antes de llamar al proveedor.
class ValidacionCredenciales {
  static const int longitudMinimaContrasena = 6;

  /// Mismo límite que firestore.rules: el nombre sale en el ranking.
  static const int longitudMaximaNombre = 80;

  static final RegExp _patronCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  const ValidacionCredenciales._();

  static bool esCorreoValido(String correo) =>
      _patronCorreo.hasMatch(correo.trim());

  static bool esContrasenaValida(String contrasena) =>
      contrasena.length >= longitudMinimaContrasena;

  /// Mensaje de error del nombre completo, o null si está bien.
  static String? errorNombre(String nombre) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return 'Ingresa tu nombre completo.';
    if (limpio.length > longitudMaximaNombre) {
      return 'Tu nombre es muy largo (máximo $longitudMaximaNombre letras).';
    }
    return null;
  }
}
