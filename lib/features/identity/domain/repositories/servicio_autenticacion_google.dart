import '../entities/usuario_autenticado.dart';

/// Contrato separado de [ServicioAutenticacion] (mismo criterio que
/// [ServicioRecuperacionContrasena]): no obliga a los dobles de prueba
/// existentes a implementar Google.
abstract class ServicioAutenticacionGoogle {
  Future<UsuarioAutenticado> iniciarConGoogle();
}
