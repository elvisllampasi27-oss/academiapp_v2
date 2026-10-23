import '../entities/usuario_academiapp.dart';
import '../repositories/repositorio_usuario.dart';
import '../repositories/servicio_autenticacion.dart';

class RegistrarEstudianteService {
  final ServicioAutenticacion servicioAutenticacion;
  final RepositorioUsuario repositorioUsuario;

  RegistrarEstudianteService({
    required this.servicioAutenticacion,
    required this.repositorioUsuario,
  });

  Future<UsuarioAcademiApp> registrar({
    required String correo,
    required String contrasena,
    required String nombre,
  }) async {
    final usuarioAutenticado = await servicioAutenticacion.registrar(
      correo: correo,
      contrasena: contrasena,
    );

    final usuario = UsuarioAcademiApp(
      uid: usuarioAutenticado.uid,
      correo: usuarioAutenticado.correo ?? correo,
      nombre: nombre,
      rol: RolUsuario.estudiante,
      estado: EstadoUsuario.activo,
      fechaCreacion: DateTime.now(),
    );

    try {
      await repositorioUsuario.guardar(usuario);
      return usuario;
    } catch (_) {
      await servicioAutenticacion.eliminarUsuarioActual();
      rethrow;
    }
  }
}
