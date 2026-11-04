import 'package:academiapp_v2/core/presentation/esqueleto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la lista en carga muestra tarjetas con forma, no un círculo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EsqueletoLista(tarjetas: 2))),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Hueso), findsNWidgets(6)); // 3 por tarjeta
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('con "reducir animaciones" el brillo no corre', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: EsqueletoInicio()),
        ),
      ),
    );
    // Si la animación siguiera, pumpAndSettle no terminaría nunca.
    await tester.pumpAndSettle();
    expect(find.byType(Hueso), findsWidgets);
  });

  testWidgets('muchas tarjetas en una pantalla baja no se desbordan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EsqueletoLista(tarjetas: 8))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
