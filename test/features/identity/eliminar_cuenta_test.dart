import 'package:academiapp_v2/features/identity/domain/repositories/servicio_eliminacion_cuenta.dart';
import 'package:academiapp_v2/features/identity/domain/values/avisos_eliminacion.dart';
import 'package:academiapp_v2/features/identity/presentation/pages/eliminar_cuenta_page.dart';
import 'package:academiapp_v2/features/premium/domain/configuracion_academia.dart';
import 'package:academiapp_v2/features/premium/domain/pago.dart';
import 'package:academiapp_v2/features/premium/domain/repositorio_premium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ServicioFalso implements ServicioEliminacionCuenta {
  final MetodoIngreso metodo;
  final ExcepcionEliminacionCuenta? fallo;
  final pasos = <String>[];

  ServicioFalso({this.metodo = MetodoIngreso.contrasena, this.fallo});

  @override
  MetodoIngreso metodoIngreso() => metodo;

  @override
  Future<void> reautenticarConContrasena(String contrasena) async {
    pasos.add('contraseña:$contrasena');
  }

  @override
  Future<void> reautenticarConGoogle() async => pasos.add('google');

  @override
  Future<void> eliminarMiCuenta() async {
    if (fallo case final fallo?) throw fallo;
    pasos.add('eliminar');
  }
}

final ahora = DateTime(2026, 11, 25, 10);

EstadoPremium estado({DateTime? hasta, bool pendiente = false}) =>
    EstadoPremium(
      configuracion: const ConfiguracionAcademia(),
      premiumHasta: hasta,
      pagos: [
        if (pendiente)
          Pago(
            id: 'yape__123456',
            usuarioId: 'u1',
            nombre: 'Ana',
            correo: 'a@b.pe',
            monto: 29,
            metodo: MetodoPago.yape,
            operacion: '123456',
            estado: EstadoPago.pendiente,
            creadoEn: DateTime(2026, 11, 24),
          ),
      ],
    );

void main() {
  group('avisos antes de eliminar', () {
    test('cuenta los días de Premium que le quedan', () {
      final avisos = AvisosEliminacion.desde(
        estado(hasta: DateTime(2026, 12, 5, 9)),
        ahora,
      );
      expect(avisos.premiumHasta, DateTime(2026, 12, 5, 9));
      // 9 días y 23 horas: se redondea a 10.
      expect(avisos.diasPremium, 10);
    });

    test('un Premium vencido no se avisa', () {
      final avisos = AvisosEliminacion.desde(
        estado(hasta: DateTime(2026, 11, 1)),
        ahora,
      );
      expect(avisos.premiumHasta, isNull);
      expect(avisos.diasPremium, 0);
    });

    test('avisa del pago en revisión', () {
      expect(
        AvisosEliminacion.desde(estado(pendiente: true), ahora).pagoPendiente,
        isTrue,
      );
      expect(AvisosEliminacion.desde(null, ahora).pagoPendiente, isFalse);
    });

    test('la confirmación es la palabra ELIMINAR', () {
      expect(confirmacionValida(' eliminar '), isTrue);
      expect(confirmacionValida('ELIMINA'), isFalse);
    });

    test('sin la función publicada, el mensaje es claro', () {
      expect(
        mensajeErrorEliminacion('not-found', null),
        'Esta opción estará disponible pronto.',
      );
      expect(
        mensajeErrorEliminacion('unauthenticated', 'Vuelve a ingresar.'),
        'Vuelve a ingresar.',
      );
    });
  });

  group('pantalla Eliminar mi cuenta', () {
    Future<void> mostrar(
      WidgetTester tester,
      ServicioFalso servicio, {
      EstadoPremium? premium,
      Future<void> Function()? onEliminada,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: EliminarCuentaPage(
            servicio: servicio,
            cargarPremium: () async => premium,
            onEliminada: onEliminada ?? () async {},
            ahora: () => ahora,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // FilledButton.icon es una subclase: se busca por "es un FilledButton".
    final botonEliminar = find.byWidgetPredicate((w) => w is FilledButton);
    FilledButton boton(WidgetTester tester) =>
        tester.widget<FilledButton>(botonEliminar);

    testWidgets('con Premium vigente avisa que no hay reembolso', (
      tester,
    ) async {
      await mostrar(
        tester,
        ServicioFalso(),
        premium: estado(hasta: DateTime(2026, 12, 5, 9), pendiente: true),
      );

      expect(find.textContaining('(10 días)'), findsOneWidget);
      expect(find.textContaining('pago en revisión'), findsOneWidget);
    });

    testWidgets('el botón se activa recién con ELIMINAR y la contraseña', (
      tester,
    ) async {
      await mostrar(tester, ServicioFalso());
      expect(boton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(0), 'eliminar');
      await tester.pump();
      expect(boton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(1), 'secreta1');
      await tester.pump();
      expect(boton(tester).onPressed, isNotNull);
    });

    testWidgets('pide la contraseña, borra y cierra la sesión', (tester) async {
      final servicio = ServicioFalso();
      var sesionCerrada = false;
      await mostrar(
        tester,
        servicio,
        onEliminada: () async => sesionCerrada = true,
      );

      await tester.enterText(find.byType(TextField).at(0), 'ELIMINAR');
      await tester.enterText(find.byType(TextField).at(1), 'secreta1');
      await tester.pump();
      await tester.tap(botonEliminar);
      await tester.pumpAndSettle();

      expect(servicio.pasos, ['contraseña:secreta1', 'eliminar']);
      expect(find.text('Tu cuenta fue eliminada'), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(sesionCerrada, isTrue);
    });

    testWidgets('con Google vuelve a pedir la cuenta de Google', (
      tester,
    ) async {
      final servicio = ServicioFalso(metodo: MetodoIngreso.google);
      await mostrar(tester, servicio);

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ELIMINAR');
      await tester.pump();
      await tester.tap(botonEliminar);
      await tester.pumpAndSettle();

      expect(servicio.pasos, ['google', 'eliminar']);
    });

    testWidgets('si falla, muestra el motivo y no cierra la sesión', (
      tester,
    ) async {
      var sesionCerrada = false;
      await mostrar(
        tester,
        ServicioFalso(
          metodo: MetodoIngreso.google,
          fallo: const ExcepcionEliminacionCuenta(
            'Esta opción estará disponible pronto.',
          ),
        ),
        onEliminada: () async => sesionCerrada = true,
      );

      await tester.enterText(find.byType(TextField), 'ELIMINAR');
      await tester.pump();
      await tester.tap(botonEliminar);
      await tester.pumpAndSettle();

      expect(
        find.text('Esta opción estará disponible pronto.'),
        findsOneWidget,
      );
      expect(sesionCerrada, isFalse);
    });
  });
}
