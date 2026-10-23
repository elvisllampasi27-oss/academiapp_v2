import 'package:academiapp_v2/features/identity/domain/entities/usuario_academiapp.dart';
import 'package:academiapp_v2/features/identity/domain/entities/usuario_autenticado.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/repositorio_usuario.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/servicio_autenticacion.dart';
import 'package:academiapp_v2/features/identity/domain/services/recuperar_sesion_estudiante_service.dart';
import 'package:flutter_test/flutter_test.dart';

class AuthFalso implements ServicioAutenticacion {
  UsuarioAutenticado? usuarioActual;

  AuthFalso(this.usuarioActual);

  @override
  UsuarioAutenticado? obtenerUsuarioActual() => usuarioActual;

  @override
  Future<void> cerrarSesion() async {
    usuarioActual = null;
  }

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

  @override
  Future<UsuarioAutenticado> iniciarSesion({
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

UsuarioAcademiApp crearUsuario({
  EstadoUsuario estado = EstadoUsuario.activo,
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
  test('devuelve null cuando Firebase no tiene sesion', () async {
    final servicio = RecuperarSesionEstudianteService(
      servicioAutenticacion: AuthFalso(null),
      repositorioUsuario: RepositorioFalso(null),
    );

    final usuario = await servicio.recuperar();

    expect(usuario, isNull);
  });

  test('recupera una sesion valida del estudiante', () async {
    final auth = AuthFalso(
      const UsuarioAutenticado(uid: 'uid-123', correo: 'alumno@academiapp.pe'),
    );

    final servicio = RecuperarSesionEstudianteService(
      servicioAutenticacion: auth,
      repositorioUsuario: RepositorioFalso(crearUsuario()),
    );

    final usuario = await servicio.recuperar();

    expect(usuario, isNotNull);
    expect(usuario!.uid, 'uid-123');
    expect(usuario.rol, RolUsuario.estudiante);
  });

  test('cierra una sesion cuyo perfil ya no existe', () async {
    final auth = AuthFalso(
      const UsuarioAutenticado(uid: 'uid-123', correo: 'alumno@academiapp.pe'),
    );

    final servicio = RecuperarSesionEstudianteService(
      servicioAutenticacion: auth,
      repositorioUsuario: RepositorioFalso(null),
    );

    final usuario = await servicio.recuperar();

    expect(usuario, isNull);
    expect(auth.obtenerUsuarioActual(), isNull);
  });

  test(
    'cierra una sesion que ya no pertenece a un estudiante activo',
    () async {
      final auth = AuthFalso(
        const UsuarioAutenticado(uid: 'uid-123', correo: 'admin@academiapp.pe'),
      );

      final servicio = RecuperarSesionEstudianteService(
        servicioAutenticacion: auth,
        repositorioUsuario: RepositorioFalso(
          crearUsuario(rol: RolUsuario.administrador),
        ),
      );

      final usuario = await servicio.recuperar();

      expect(usuario, isNull);
      expect(auth.obtenerUsuarioActual(), isNull);
    },
  );
}
