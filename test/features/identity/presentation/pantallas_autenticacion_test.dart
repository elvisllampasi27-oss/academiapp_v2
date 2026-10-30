import 'package:academiapp_v2/features/identity/domain/entities/usuario_academiapp.dart';
import 'package:academiapp_v2/features/identity/domain/errors/excepcion_autenticacion.dart';
import 'package:academiapp_v2/features/identity/domain/services/iniciar_sesion_estudiante_service.dart';
import 'package:academiapp_v2/features/identity/domain/services/recuperar_contrasena_service.dart';
import 'package:academiapp_v2/features/identity/domain/services/registrar_estudiante_service.dart';
import 'package:academiapp_v2/features/identity/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes_identidad.dart';

void main() {
  late AuthFalsoConfigurable auth;
  late RepositorioUsuarioEnMemoria repositorio;
  late int sesionesIniciadas;

  Widget construirLogin() {
    return MaterialApp(
      home: LoginPage(
        iniciarSesionService: IniciarSesionEstudianteService(
          servicioAutenticacion: auth,
          repositorioUsuario: repositorio,
        ),
        registrarService: RegistrarEstudianteService(
          servicioAutenticacion: auth,
          repositorioUsuario: repositorio,
        ),
        recuperarContrasenaService: RecuperarContrasenaService(servicio: auth),
        onSesionIniciada: () => sesionesIniciadas++,
      ),
    );
  }

  setUp(() {
    auth = AuthFalsoConfigurable();
    repositorio = RepositorioUsuarioEnMemoria();
    sesionesIniciadas = 0;
  });

  Future<void> mostrar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(construirLogin());
  }

  testWidgets('pide el correo si se envia vacio', (tester) async {
    await mostrar(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresa tu correo.'), findsOneWidget);
    expect(sesionesIniciadas, 0);
  });

  testWidgets('muestra mensaje amigable con credenciales invalidas', (
    tester,
  ) async {
    auth.errorAlIniciar = const ExcepcionAutenticacion(
      TipoErrorAutenticacion.credencialesInvalidas,
    );
    await mostrar(tester);

    await tester.enterText(find.byType(TextField).at(0), 'a@b.pe');
    await tester.enterText(find.byType(TextField).at(1), 'mala123');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('inicia sesion con un estudiante activo', (tester) async {
    repositorio.usuarios['uid-1'] = UsuarioAcademiApp(
      uid: 'uid-1',
      correo: 'a@b.pe',
      nombre: 'Ana',
      rol: RolUsuario.estudiante,
      estado: EstadoUsuario.activo,
      fechaCreacion: DateTime(2026, 10, 1),
    );
    await mostrar(tester);

    await tester.enterText(find.byType(TextField).at(0), 'a@b.pe');
    await tester.enterText(find.byType(TextField).at(1), 'buena123');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(sesionesIniciadas, 1);
  });

  testWidgets('el registro valida que las contrasenas coincidan', (
    tester,
  ) async {
    await mostrar(tester);

    await tester.tap(find.text('Registrarse aquí'));
    await tester.pumpAndSettle();

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Ana Quispe');
    await tester.enterText(campos.at(1), 'ana@academiapp.pe');
    await tester.enterText(campos.at(2), 'secreta1');
    await tester.enterText(campos.at(3), 'distinta1');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(repositorio.usuarios, isEmpty);
  });

  testWidgets('recuperar contrasena confirma el envio', (tester) async {
    await mostrar(tester);

    await tester.enterText(find.byType(TextField).at(0), 'ana@academiapp.pe');
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(auth.correosRecuperacion, ['ana@academiapp.pe']);
  });
}
