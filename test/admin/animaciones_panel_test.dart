import 'package:academiapp_v2/admin/graficos.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/admin/widgets_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget panel(Widget hijo) => MaterialApp(
  theme: temaPanel(),
  home: Scaffold(body: hijo),
);

void main() {
  testWidgets('las cifras cuentan desde cero y terminan en su valor', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel(const ValorAnimado('S/ 290', estilo: TextStyle(fontSize: 20))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('S/ 290'), findsNothing); // todavía contando

    await tester.pumpAndSettle();
    expect(find.text('S/ 290'), findsOneWidget);
  });

  testWidgets('un valor sin número se muestra tal cual', (tester) async {
    await tester.pumpWidget(
      panel(const ValorAnimado('—', estilo: TextStyle(fontSize: 20))),
    );
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('el anillo se llena hasta su porcentaje', (tester) async {
    await tester.pumpWidget(panel(const Center(child: AnilloAvance(0.72))));
    await tester.pumpAndSettle();
    expect(find.text('72%'), findsOneWidget);
  });

  testWidgets('las tarjetas de cifras entran y quedan visibles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      panel(
        const RejillaPanel(
          children: [
            IndicadorPanel(etiqueta: 'Activos', valor: '12'),
            IndicadorPanel(etiqueta: 'Premium', valor: '5'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    final opacidades = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity);
    expect(opacidades, everyElement(1.0));
  });

  testWidgets('mientras carga, la página muestra su esqueleto', (tester) async {
    await tester.pumpWidget(
      panel(
        FuturoPanel<int>(
          futuro: Future.delayed(const Duration(seconds: 1), () => 1),
          onReintentar: () {},
          builder: (context, n) => Text('listo $n'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(EsqueletoPanel), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('listo 1'), findsOneWidget);
  });
}
