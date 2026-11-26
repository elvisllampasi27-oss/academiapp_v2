import 'package:academiapp_v2/features/enrollment/domain/services/servicio_preparacion_cuenta.dart';
import 'package:academiapp_v2/features/enrollment/infrastructure/services/firebase_servicio_preparacion_cuenta.dart';
import 'package:academiapp_v2/features/enrollment/presentation/preparar_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ServicioFalso implements ServicioPreparacionCuenta {
  final List<Object> respuestas;
  int llamadas = 0;

  /// Cada llamada devuelve (o lanza) la siguiente respuesta.
  ServicioFalso(this.respuestas);

  @override
  Future<PlanPreparado> preparar() async {
    final r = respuestas[llamadas++];
    if (r is PlanPreparado) return r;
    throw r;
  }
}

final nuevo = PlanPreparado(
  nuevo: true,
  versionNombre: 'Ciclo 2027-I',
  inicio: DateTime(2026, 11, 30),
  pruebaHasta: DateTime(2026, 12, 7),
);

void main() {
  test('lee la respuesta de prepararCuenta', () {
    final plan = planDesdeMapa({
      'nueva': true,
      'versionNombre': 'Ciclo 2027-I',
      'inicioMs': DateTime(2026, 11, 30).millisecondsSinceEpoch,
      'pruebaHastaMs': DateTime(2026, 12, 7).millisecondsSinceEpoch,
    });
    expect(plan.nuevo, isTrue);
    expect(plan.inicio, DateTime(2026, 11, 30));
    // La prueba termina el lunes a las 00:00: el último día es el domingo.
    expect(plan.ultimoDiaPrueba, DateTime(2026, 12, 6));
    expect(planDesdeMapa({'nueva': false}).pruebaHasta, isNull);
  });

  test('sin la función publicada, el mensaje es claro', () {
    expect(mensajeErrorPreparacion('not-found', null), contains('pronto'));
    expect(
      mensajeErrorPreparacion('failed-precondition', 'Matrículas cerradas.'),
      'Matrículas cerradas.',
    );
  });

  group('PrepararPlan', () {
    late int listos;

    Future<void> mostrar(WidgetTester tester, ServicioFalso servicio) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PrepararPlan(
            servicio: servicio,
            nombre: 'Ana Quispe',
            onListo: () => listos++,
            siFalla: (mensaje, reintentar) => Scaffold(
              body: Column(
                children: [
                  Text(mensaje),
                  TextButton(
                    onPressed: reintentar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    setUp(() => listos = 0);

    testWidgets('alumno nuevo: bienvenida con su inicio y su prueba', (
      tester,
    ) async {
      await mostrar(tester, ServicioFalso([nuevo]));
      await tester.pumpAndSettle();

      expect(find.text('¡Bienvenido a Sinchi, Ana!'), findsOneWidget);
      expect(find.textContaining('lunes 30 nov'), findsOneWidget);
      expect(find.textContaining('hasta el domingo 6 dic'), findsOneWidget);
      expect(listos, 0);

      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      expect(listos, 1);
    });

    testWidgets('si ya tenía plan, entra sin bienvenida', (tester) async {
      await mostrar(tester, ServicioFalso([const PlanPreparado(nuevo: false)]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bienvenido'), findsNothing);
      expect(listos, 1);
    });

    testWidgets('si falla, muestra el motivo y se puede reintentar', (
      tester,
    ) async {
      final servicio = ServicioFalso([
        const ExcepcionPreparacionCuenta(
          'Las matrículas están cerradas por ahora.',
        ),
        const PlanPreparado(nuevo: false),
      ]);
      await mostrar(tester, servicio);
      await tester.pumpAndSettle();

      expect(
        find.text('Las matrículas están cerradas por ahora.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(servicio.llamadas, 2);
      expect(listos, 1);
    });
  });
}
