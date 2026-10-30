import '../entities/usuario_academiapp.dart';
import '../entities/usuario_autenticado.dart';
import '../repositories/repositorio_usuario.dart';
import '../repositories/servicio_autenticacion.dart';
import '../repositories/servicio_autenticacion_google.dart';

/// Resultado de entrar con Google: o el estudiante ya tiene perfil,
/// o es su primera vez y debe completarlo.
sealed class ResultadoInicioGoogle {
  const ResultadoInicioGoogle();
}

class InicioGoogleCompleto extends ResultadoInicioGoogle {
  final UsuarioAcademiApp usuario;

  const InicioGoogleCompleto(this.usuario);
}

class InicioGoogleRequierePerfil extends ResultadoInicioGoogle {
  final UsuarioAutenticado autenticado;

  const InicioGoogleRequierePerfil(this.autenticado);
}

class IniciarSesionGoogleService {
  final ServicioAutenticacionGoogle servicioGoogle;
  final ServicioAutenticacion servicioAutenticacion;
  final RepositorioUsuario repositorioUsuario;

  const IniciarSesionGoogleService({
    required this.servicioGoogle,
    required this.servicioAutenticacion,
    required this.repositorioUsuario,
  });

  Future<ResultadoInicioGoogle> iniciar() async {
    final autenticado = await servicioGoogle.iniciarConGoogle();

    final usuario = await repositorioUsuario.buscarPorUid(autenticado.uid);

    if (usuario == null) {
      return InicioGoogleRequierePerfil(autenticado);
    }

    // Mismas reglas que el inicio con correo y contraseña.
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

    return InicioGoogleCompleto(usuario);
  }
}
