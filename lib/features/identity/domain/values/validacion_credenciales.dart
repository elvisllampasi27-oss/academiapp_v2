/// Reglas mínimas de formato para correo y contraseña.
/// Firebase vuelve a validar en el servidor; esto evita viajes inútiles
/// y permite mostrar mensajes claros antes de llamar al proveedor.
class ValidacionCredenciales {
  static const int longitudMinimaContrasena = 6;

  static final RegExp _patronCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  const ValidacionCredenciales._();

  static bool esCorreoValido(String correo) =>
      _patronCorreo.hasMatch(correo.trim());

  static bool esContrasenaValida(String contrasena) =>
      contrasena.length >= longitudMinimaContrasena;
}
