import 'package:academiapp_v2/features/identity/domain/entities/usuario_academiapp.dart';
import 'package:academiapp_v2/features/identity/domain/entities/usuario_autenticado.dart';
import 'package:academiapp_v2/features/identity/domain/errors/excepcion_autenticacion.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/repositorio_usuario.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/servicio_autenticacion.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/servicio_recuperacion_contrasena.dart';

/// Dobles de prueba compartidos por los tests del bloque 12.13.
class AuthFalsoConfigurable
    implements ServicioAutenticacion, ServicioRecuperacionContrasena {
  ExcepcionAutenticacion? errorAlIniciar;
  ExcepcionAutenticacion? errorAlRegistrar;
  UsuarioAutenticado? usuarioActual;
  final List<String> correosRecuperacion = [];

  @override
  Future<UsuarioAutenticado> registrar({
    required String correo,
    required String contrasena,
  }) async {
    if (errorAlRegistrar != null) throw errorAlRegistrar!;
    usuarioActual = UsuarioAutenticado(uid: 'uid-nuevo', correo: correo);
    return usuarioActual!;
  }

  @override
  Future<UsuarioAutenticado> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    if (errorAlIniciar != null) throw errorAlIniciar!;
    usuarioActual = UsuarioAutenticado(uid: 'uid-1', correo: correo);
    return usuarioActual!;
  }

  @override
  Future<void> enviarCorreoRecuperacion(String correo) async {
    correosRecuperacion.add(correo);
  }

  @override
  Future<void> cerrarSesion() async {
    usuarioActual = null;
  }

  @override
  Future<void> eliminarUsuarioActual() async {
    usuarioActual = null;
  }

  @override
  UsuarioAutenticado? obtenerUsuarioActual() => usuarioActual;
}

class RepositorioUsuarioEnMemoria implements RepositorioUsuario {
  final Map<String, UsuarioAcademiApp> usuarios = {};

  @override
  Future<void> guardar(UsuarioAcademiApp usuario) async {
    usuarios[usuario.uid] = usuario;
  }

  @override
  Future<UsuarioAcademiApp?> buscarPorUid(String uid) async => usuarios[uid];
}
