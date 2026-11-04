import 'package:academiapp_v2/core/presentation/imagen_figura.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la figura no pasa del 40 % del alto y se amplía al tocarla', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ImagenFigura('https://ejemplo.pe/figura.png'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final caja = tester.getSize(
      find
          .descendant(
            of: find.byType(ImagenFigura),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(caja.height, lessThanOrEqualTo(320));

    await tester.tap(find.byType(ImagenFigura));
    await tester.pumpAndSettle();
    expect(find.text('Figura'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
