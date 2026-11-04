import 'package:academiapp_v2/core/presentation/desplegables.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget solucion({required bool abierta}) => MaterialApp(
    home: Scaffold(
      body: SolucionDesplegable(
        abierta: abierta,
        child: const Text('Porque 2 + 2 = 4.'),
      ),
    ),
  );

  testWidgets('si acertó, la solución empieza cerrada y se abre al tocar', (
    tester,
  ) async {
    await tester.pumpWidget(solucion(abierta: false));
    expect(find.text('Porque 2 + 2 = 4.'), findsNothing);

    await tester.tap(find.text('Ver solución'));
    await tester.pumpAndSettle();
    expect(find.text('Porque 2 + 2 = 4.'), findsOneWidget);
    expect(find.text('Ocultar solución'), findsOneWidget);
  });

  testWidgets('si falló, la solución empieza abierta', (tester) async {
    await tester.pumpWidget(solucion(abierta: true));
    expect(find.text('Porque 2 + 2 = 4.'), findsOneWidget);
  });

  testWidgets('las tarjetas aparecen y quedan en su lugar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Aparecer(indice: 0, child: Text('uno')),
              Aparecer(indice: 3, child: Text('dos')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final opacidades = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity);
    expect(opacidades, everyElement(1.0));
  });
}
