import '../entities/usuario_academiapp.dart';
import '../entities/usuario_autenticado.dart';
import '../repositories/repositorio_usuario.dart';
import '../repositories/servicio_autenticacion.dart';

/// Crea el perfil de AcademiApp para quien entró por un proveedor externo
/// (Google) y todavía no lo tiene.
class CompletarPerfilService {
  final ServicioAutenticacion servicioAutenticacion;
  final RepositorioUsuario repositorioUsuario;

  const CompletarPerfilService({
    required this.servicioAutenticacion,
    required this.repositorioUsuario,
  });

  Future<UsuarioAcademiApp> completar({
    required UsuarioAutenticado autenticado,
    required String nombre,
    String? carreraPostulada,
  }) async {
    final correo = autenticado.correo;

    if (correo == null || correo.isEmpty) {
      throw StateError('La cuenta de Google no tiene un correo asociado.');
    }

    if (nombre.trim().isEmpty) {
      throw StateError('Ingresa tu nombre completo.');
    }

    final usuario = UsuarioAcademiApp(
      uid: autenticado.uid,
      correo: correo,
      nombre: nombre.trim(),
      rol: RolUsuario.estudiante,
      estado: EstadoUsuario.activo,
      fechaCreacion: DateTime.now(),
      carreraPostulada: carreraPostulada,
    );

    await repositorioUsuario.guardar(usuario);

    return usuario;
  }

  /// Si el estudiante abandona el formulario, no queda una sesión a medias.
  Future<void> cancelar() => servicioAutenticacion.cerrarSesion();
}
