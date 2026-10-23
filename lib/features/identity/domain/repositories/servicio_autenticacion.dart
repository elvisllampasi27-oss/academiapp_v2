import '../entities/usuario_autenticado.dart';

abstract class ServicioAutenticacion {
  Future<UsuarioAutenticado> registrar({
    required String correo,
    required String contrasena,
  });

  Future<UsuarioAutenticado> iniciarSesion({
    required String correo,
    required String contrasena,
  });

  Future<void> cerrarSesion();

  Future<void> eliminarUsuarioActual();

  UsuarioAutenticado? obtenerUsuarioActual();
}
