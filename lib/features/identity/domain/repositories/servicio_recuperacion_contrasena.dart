/// Contrato separado de [ServicioAutenticacion] para no obligar a todas
/// sus implementaciones (incluidos los dobles de prueba) a soportarlo.
abstract class ServicioRecuperacionContrasena {
  Future<void> enviarCorreoRecuperacion(String correo);
}
