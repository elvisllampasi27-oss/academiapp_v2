import 'package:academiapp_v2/features/identity/domain/entities/usuario_academiapp.dart';
import 'package:academiapp_v2/features/identity/domain/entities/usuario_autenticado.dart';
import 'package:academiapp_v2/features/identity/domain/services/completar_perfil_service.dart';
import 'package:academiapp_v2/features/identity/domain/services/iniciar_sesion_google_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes_identidad.dart';

void main() {
  late AuthFalsoConfigurable auth;
  late RepositorioUsuarioEnMemoria repositorio;
  late IniciarSesionGoogleService google;
  late CompletarPerfilService completar;

  setUp(() {
    auth = AuthFalsoConfigurable();
    repositorio = RepositorioUsuarioEnMemoria();
    google = IniciarSesionGoogleService(
      servicioGoogle: auth,
      servicioAutenticacion: auth,
      repositorioUsuario: repositorio,
    );
    completar = CompletarPerfilService(
      servicioAutenticacion: auth,
      repositorioUsuario: repositorio,
    );
  });

  UsuarioAcademiApp perfil({
    EstadoUsuario estado = EstadoUsuario.activo,
    RolUsuario rol = RolUsuario.estudiante,
  }) {
    return UsuarioAcademiApp(
      uid: 'uid-google',
      correo: 'ana@gmail.com',
      nombre: 'Ana',
      rol: rol,
      estado: estado,
      fechaCreacion: DateTime(2026, 10, 1),
    );
  }

  test('sin perfil devuelve RequierePerfil con los datos de Google', () async {
    final resultado = await google.iniciar();

    expect(resultado, isA<InicioGoogleRequierePerfil>());
    final autenticado = (resultado as InicioGoogleRequierePerfil).autenticado;
    expect(autenticado.nombre, 'Ana Quispe');
    expect(auth.usuarioActual, isNotNull);
  });

  test('con perfil activo devuelve Completo', () async {
    repositorio.usuarios['uid-google'] = perfil();

    final resultado = await google.iniciar();

    expect(resultado, isA<InicioGoogleCompleto>());
  });

  test('con perfil inactivo cierra la sesion', () async {
    repositorio.usuarios['uid-google'] = perfil(estado: EstadoUsuario.inactivo);

    await expectLater(google.iniciar(), throwsStateError);
    expect(auth.usuarioActual, isNull);
  });

  test('un administrador no entra por la app del estudiante', () async {
    repositorio.usuarios['uid-google'] = perfil(rol: RolUsuario.administrador);

    await expectLater(google.iniciar(), throwsStateError);
    expect(auth.usuarioActual, isNull);
  });

  test('completar perfil crea un estudiante activo', () async {
    final usuario = await completar.completar(
      autenticado: const UsuarioAutenticado(
        uid: 'uid-google',
        correo: 'ana@gmail.com',
      ),
      nombre: '  Ana Quispe  ',
      carreraPostulada: 'Derecho',
    );

    expect(usuario.nombre, 'Ana Quispe');
    expect(usuario.rol, RolUsuario.estudiante);
    expect(usuario.estado, EstadoUsuario.activo);
    expect(repositorio.usuarios['uid-google']?.carreraPostulada, 'Derecho');
  });

  test('completar perfil exige nombre', () {
    expect(
      () => completar.completar(
        autenticado: const UsuarioAutenticado(uid: 'u', correo: 'a@b.pe'),
        nombre: '   ',
      ),
      throwsStateError,
    );
  });

  test('cancelar el perfil cierra la sesion', () async {
    await auth.iniciarConGoogle();

    await completar.cancelar();

    expect(auth.usuarioActual, isNull);
  });
}
