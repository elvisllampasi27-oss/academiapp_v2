import 'package:academiapp_v2/features/identity/domain/entities/estado_sesion_estudiante.dart';
import 'package:academiapp_v2/features/identity/domain/entities/usuario_academiapp.dart';
import 'package:academiapp_v2/features/identity/domain/entities/usuario_autenticado.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/repositorio_usuario.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/servicio_autenticacion.dart';
import 'package:academiapp_v2/features/identity/domain/services/recuperar_sesion_estudiante_service.dart';
import 'package:academiapp_v2/features/identity/domain/services/resolver_estado_inicial_sesion_service.dart';
import 'package:flutter_test/flutter_test.dart';

class ServicioAutenticacionFalso implements ServicioAutenticacion {
  UsuarioAutenticado? usuarioActual;

  ServicioAutenticacionFalso({this.usuarioActual});

  @override
  UsuarioAutenticado? obtenerUsuarioActual() => usuarioActual;

  @override
  Future<UsuarioAutenticado> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async => throw UnimplementedError();

  @override
  Future<UsuarioAutenticado> registrar({
    required String correo,
    required String contrasena,
  }) async => throw UnimplementedError();

  @override
  Future<void> cerrarSesion() async => usuarioActual = null;

  @override
  Future<void> eliminarUsuarioActual() async => usuarioActual = null;
}

class RepositorioUsuarioFalso implements RepositorioUsuario {
  final UsuarioAcademiApp? usuario;

  RepositorioUsuarioFalso(this.usuario);

  @override
  Future<UsuarioAcademiApp?> buscarPorUid(String uid) async => usuario;

  @override
  Future<void> guardar(UsuarioAcademiApp usuario) async {}
}

void main() {
  final usuarioPrueba = UsuarioAcademiApp(
    uid: 'uid-123',
    correo: 'alumno@academiapp.pe',
    nombre: 'Alumno Test',
    rol: RolUsuario.estudiante,
    estado: EstadoUsuario.activo,
    fechaCreacion: DateTime(2026, 10, 22),
  );

  test(
    'retorna EstadoSesionEstudiante.noAutenticado cuando no hay usuario activo',
    () async {
      final recuperarSesion = RecuperarSesionEstudianteService(
        servicioAutenticacion: ServicioAutenticacionFalso(usuarioActual: null),
        repositorioUsuario: RepositorioUsuarioFalso(null),
      );

      final resolverService = ResolverEstadoInicialSesionService(
        recuperarSesion: recuperarSesion,
      );

      final estado = await resolverService.resolver();

      expect(estado, equals(const EstadoSesionEstudiante.noAutenticado()));
    },
  );

  test('retorna EstadoSesionEstudiante.autenticado cuando existe usuario en sesion', () async {
    final recuperarSesion = RecuperarSesionEstudianteService(
      servicioAutenticacion: ServicioAutenticacionFalso(
        usuarioActual: UsuarioAutenticado(
          uid: 'uid-123',
          correo: 'alumno@academiapp.pe',
        ),
      ),
      repositorioUsuario: RepositorioUsuarioFalso(usuarioPrueba),
    );

    final resolverService = ResolverEstadoInicialSesionService(
      recuperarSesion: recuperarSesion,
    );

    final estado = await resolverService.resolver();

    expect(estado.usuario, equals(usuarioPrueba));
  });
}
