import 'package:academiapp_v2/admin/animacion_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la entrada desenfocada termina sin ningún efecto encima', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EntradaDifuminada(child: Text('Hola'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(ImageFiltered), findsOneWidget); // aún entrando

    await tester.pumpAndSettle();
    expect(find.text('Hola'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(
      find.ancestor(of: find.text('Hola'), matching: find.byType(Opacity)),
      findsNothing,
    );
  });

  testWidgets('la cifra cuenta y termina en su valor exacto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NumeroQueCuenta('S/ 290', estilo: TextStyle(fontSize: 20)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('S/ 290'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('S/ 290'), findsOneWidget);
  });

  testWidgets('con "reducir animaciones" todo aparece directo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Column(
              children: [
                EntradaDifuminada(child: Text('Hola')),
                NumeroQueCuenta('12', estilo: TextStyle()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('las filas entran una tras otra y quedan limpias', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (var i = 0; i < 3; i++)
                FilaEntrante(indice: i, child: Text('fila $i')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(
        find.ancestor(of: find.text('fila $i'), matching: find.byType(Opacity)),
        findsNothing,
      );
    }
  });
}
