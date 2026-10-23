import '../entities/usuario_academiapp.dart';
import '../repositories/repositorio_usuario.dart';
import '../repositories/servicio_autenticacion.dart';

class RecuperarSesionEstudianteService {
  final ServicioAutenticacion servicioAutenticacion;
  final RepositorioUsuario repositorioUsuario;

  RecuperarSesionEstudianteService({
    required this.servicioAutenticacion,
    required this.repositorioUsuario,
  });

  Future<UsuarioAcademiApp?> recuperar() async {
    final autenticado = servicioAutenticacion.obtenerUsuarioActual();

    if (autenticado == null) {
      return null;
    }

    final usuario = await repositorioUsuario.buscarPorUid(autenticado.uid);

    if (usuario == null ||
        usuario.estado != EstadoUsuario.activo ||
        usuario.rol != RolUsuario.estudiante) {
      await servicioAutenticacion.cerrarSesion();
      return null;
    }

    return usuario;
  }
}
