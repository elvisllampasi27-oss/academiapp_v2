import '../entities/usuario_academiapp.dart';
import '../repositories/repositorio_usuario.dart';
import '../repositories/servicio_autenticacion.dart';

class IniciarSesionEstudianteService {
  final ServicioAutenticacion servicioAutenticacion;
  final RepositorioUsuario repositorioUsuario;

  IniciarSesionEstudianteService({
    required this.servicioAutenticacion,
    required this.repositorioUsuario,
  });

  Future<UsuarioAcademiApp> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final autenticado = await servicioAutenticacion.iniciarSesion(
      correo: correo,
      contrasena: contrasena,
    );

    final usuario = await repositorioUsuario.buscarPorUid(autenticado.uid);

    if (usuario == null) {
      await servicioAutenticacion.cerrarSesion();

      throw StateError(
        'El usuario autenticado no tiene un perfil en AcademiApp.',
      );
    }

    if (usuario.estado != EstadoUsuario.activo) {
      await servicioAutenticacion.cerrarSesion();

      throw StateError('La cuenta del estudiante no esta activa.');
    }

    if (usuario.rol != RolUsuario.estudiante) {
      await servicioAutenticacion.cerrarSesion();

      throw StateError(
        'Este usuario no tiene acceso a la aplicacion de estudiantes.',
      );
    }

    return usuario;
  }
}
