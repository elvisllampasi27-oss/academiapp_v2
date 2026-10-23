import 'package:academiapp_v2/features/identity/domain/entities/usuario_academiapp.dart';
import 'package:academiapp_v2/features/identity/domain/entities/usuario_autenticado.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/repositorio_usuario.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/servicio_autenticacion.dart';
import 'package:academiapp_v2/features/identity/domain/services/iniciar_sesion_estudiante_service.dart';
import 'package:flutter_test/flutter_test.dart';

class AuthFalso implements ServicioAutenticacion {
  UsuarioAutenticado? usuarioActual;

  @override
  Future<UsuarioAutenticado> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    usuarioActual = UsuarioAutenticado(uid: 'uid-123', correo: correo);
    return usuarioActual!;
  }

  @override
  Future<void> cerrarSesion() async {
    usuarioActual = null;
  }

  @override
  UsuarioAutenticado? obtenerUsuarioActual() => usuarioActual;

  @override
  Future<void> eliminarUsuarioActual() async {
    usuarioActual = null;
  }

  @override
  Future<UsuarioAutenticado> registrar({
    required String correo,
    required String contrasena,
  }) {
    throw UnimplementedError();
  }
}

class RepositorioFalso implements RepositorioUsuario {
  final UsuarioAcademiApp? usuario;

  RepositorioFalso(this.usuario);

  @override
  Future<UsuarioAcademiApp?> buscarPorUid(String uid) async => usuario;

  @override
  Future<void> guardar(UsuarioAcademiApp usuario) async {}
}

UsuarioAcademiApp crearUsuario(
  EstadoUsuario estado, {
  RolUsuario rol = RolUsuario.estudiante,
}) {
  return UsuarioAcademiApp(
    uid: 'uid-123',
    correo: 'alumno@academiapp.pe',
    nombre: 'Alumno',
    rol: rol,
    estado: estado,
    fechaCreacion: DateTime(2026, 10, 22),
  );
}

void main() {
  test('permite iniciar sesion cuando el estudiante esta activo', () async {
    final servicio = IniciarSesionEstudianteService(
      servicioAutenticacion: AuthFalso(),
      repositorioUsuario: RepositorioFalso(crearUsuario(EstadoUsuario.activo)),
    );

    final usuario = await servicio.iniciarSesion(
      correo: 'alumno@academiapp.pe',
      contrasena: 'Prueba123!',
    );

    expect(usuario.uid, 'uid-123');
    expect(usuario.estado, EstadoUsuario.activo);
  });

  test('cierra sesion cuando no existe perfil en AcademiApp', () async {
    final auth = AuthFalso();

    final servicio = IniciarSesionEstudianteService(
      servicioAutenticacion: auth,
      repositorioUsuario: RepositorioFalso(null),
    );

    await expectLater(
      servicio.iniciarSesion(
        correo: 'alumno@academiapp.pe',
        contrasena: 'Prueba123!',
      ),
      throwsStateError,
    );

    expect(auth.obtenerUsuarioActual(), isNull);
  });

  test('cierra sesion cuando la cuenta esta inactiva', () async {
    final auth = AuthFalso();

    final servicio = IniciarSesionEstudianteService(
      servicioAutenticacion: auth,
      repositorioUsuario: RepositorioFalso(
        crearUsuario(EstadoUsuario.inactivo),
      ),
    );

    await expectLater(
      servicio.iniciarSesion(
        correo: 'alumno@academiapp.pe',
        contrasena: 'Prueba123!',
      ),
      throwsStateError,
    );

    expect(auth.obtenerUsuarioActual(), isNull);
  });

  test('rechaza administradores en la aplicacion de estudiantes', () async {
    final auth = AuthFalso();

    final servicio = IniciarSesionEstudianteService(
      servicioAutenticacion: auth,
      repositorioUsuario: RepositorioFalso(
        crearUsuario(EstadoUsuario.activo, rol: RolUsuario.administrador),
      ),
    );

    await expectLater(
      servicio.iniciarSesion(
        correo: 'admin@academiapp.pe',
        contrasena: 'Prueba123!',
      ),
      throwsStateError,
    );

    expect(auth.obtenerUsuarioActual(), isNull);
  });
}
