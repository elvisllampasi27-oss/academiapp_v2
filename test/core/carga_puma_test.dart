import 'package:academiapp_v2/core/presentation/carga_puma.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo) => MaterialApp(
  home: Scaffold(body: Center(child: hijo)),
);

void main() {
  testWidgets('sin la señal de "lista" nunca se completa', (tester) async {
    var completos = 0;
    await tester.pumpWidget(_app(CargaPuma(alCompletar: () => completos++)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle(); // avanza sola y se detiene en su tope

    expect(completos, 0);
  });

  testWidgets('con "lista" termina de formarse y avisa una sola vez', (
    tester,
  ) async {
    var completos = 0;
    Widget carga(bool lista) =>
        _app(CargaPuma(lista: lista, alCompletar: () => completos++));

    await tester.pumpWidget(carga(false));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(carga(true));
    await tester.pumpAndSettle();
    expect(completos, 1);

    await tester.pumpWidget(carga(true));
    await tester.pumpAndSettle();
    expect(completos, 1);
  });

  testWidgets('las pantallas del arranque comparten el avance', (tester) async {
    final avance = ValueNotifier<double>(0);
    addTearDown(avance.dispose);

    await tester.pumpWidget(_app(CargaPuma(avanceCompartido: avance)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final llevado = avance.value;
    expect(llevado, greaterThan(0));
    expect(llevado, lessThanOrEqualTo(CargaPuma.tope));

    // Al completarse, la próxima carga vuelve a empezar de cero.
    await tester.pumpWidget(
      _app(CargaPuma(avanceCompartido: avance, lista: true)),
    );
    await tester.pumpAndSettle();
    expect(avance.value, 0);
  });

  testWidgets('la versión chica no aparece en cargas muy cortas', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const CargaPuma.compacta()));
    Opacity opacidad() => tester.widget(
      find.descendant(
        of: find.byType(CargaPuma),
        matching: find.byType(Opacity),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacidad().opacity, 0);

    await tester.pump(const Duration(milliseconds: 400));
    expect(opacidad().opacity, 1);
  });

  testWidgets('con "reducir animaciones" se completa al instante', (
    tester,
  ) async {
    var completos = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: CargaPuma(lista: true, alCompletar: () => completos++),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(completos, 1);
  });
}
