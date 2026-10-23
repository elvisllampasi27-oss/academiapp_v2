import 'package:academiapp_v2/features/identity/domain/entities/usuario_academiapp.dart';
import 'package:academiapp_v2/features/identity/domain/entities/usuario_autenticado.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/repositorio_usuario.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/servicio_autenticacion.dart';
import 'package:academiapp_v2/features/identity/domain/services/registrar_estudiante_service.dart';
import 'package:flutter_test/flutter_test.dart';

class ServicioAutenticacionFalso implements ServicioAutenticacion {
  UsuarioAutenticado? usuarioActual;

  @override
  Future<UsuarioAutenticado> registrar({
    required String correo,
    required String contrasena,
  }) async {
    usuarioActual = UsuarioAutenticado(uid: 'uid-123', correo: correo);

    return usuarioActual!;
  }

  @override
  Future<UsuarioAutenticado> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    throw UnimplementedError();
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
  UsuarioAutenticado? obtenerUsuarioActual() {
    return usuarioActual;
  }
}

class RepositorioUsuarioFalso implements RepositorioUsuario {
  final Map<String, UsuarioAcademiApp> usuarios = {};

  @override
  Future<void> guardar(UsuarioAcademiApp usuario) async {
    usuarios[usuario.uid] = usuario;
  }

  @override
  Future<UsuarioAcademiApp?> buscarPorUid(String uid) async {
    return usuarios[uid];
  }
}

class RepositorioUsuarioConFallo implements RepositorioUsuario {
  @override
  Future<void> guardar(UsuarioAcademiApp usuario) async {
    throw Exception('Firestore no disponible');
  }

  @override
  Future<UsuarioAcademiApp?> buscarPorUid(String uid) async {
    return null;
  }
}

void main() {
  test('registra estudiante en Auth y guarda su perfil', () async {
    final autenticacion = ServicioAutenticacionFalso();
    final repositorio = RepositorioUsuarioFalso();

    final servicio = RegistrarEstudianteService(
      servicioAutenticacion: autenticacion,
      repositorioUsuario: repositorio,
    );

    final usuario = await servicio.registrar(
      correo: 'nuevo@academiapp.pe',
      contrasena: 'Prueba123!',
      nombre: 'Nuevo Estudiante',
    );

    expect(usuario.uid, 'uid-123');
    expect(usuario.correo, 'nuevo@academiapp.pe');
    expect(usuario.nombre, 'Nuevo Estudiante');
    expect(usuario.rol, RolUsuario.estudiante);
    expect(usuario.estado, EstadoUsuario.activo);

    final guardado = await repositorio.buscarPorUid('uid-123');

    expect(guardado, isNotNull);
    expect(guardado!.uid, usuario.uid);
    expect(guardado.rol, RolUsuario.estudiante);
  });

  test('elimina la cuenta de Auth si falla el guardado del perfil', () async {
    final autenticacion = ServicioAutenticacionFalso();

    final servicio = RegistrarEstudianteService(
      servicioAutenticacion: autenticacion,
      repositorioUsuario: RepositorioUsuarioConFallo(),
    );

    await expectLater(
      servicio.registrar(
        correo: 'nuevo@academiapp.pe',
        contrasena: 'Prueba123!',
        nombre: 'Nuevo Estudiante',
      ),
      throwsException,
    );

    expect(autenticacion.obtenerUsuarioActual(), isNull);
  });
}
