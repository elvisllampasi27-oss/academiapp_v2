import 'dart:async';

import 'package:academiapp_v2/admin/animacion_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la entrada desenfocada termina con sus efectos neutros', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EntradaDifuminada(child: Text('Hola'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    ImageFiltered filtro() => tester.widget(find.byType(ImageFiltered));
    Opacity opacidad() => tester.widget(
      find.ancestor(of: find.text('Hola'), matching: find.byType(Opacity)),
    );
    expect(filtro().enabled, isTrue); // aún entrando
    expect(opacidad().opacity, lessThan(1));

    await tester.pumpAndSettle();
    expect(find.text('Hola'), findsOneWidget);
    expect(filtro().enabled, isFalse);
    expect(opacidad().opacity, 1);
  });

  testWidgets('al terminar no vuelve a montar el contenido (conserva estado)', (
    tester,
  ) async {
    // Un stream de una sola suscripción: si el contenido se montara de
    // nuevo al terminar la animación, fallaría con "already been listened".
    final controlador = StreamController<int>();
    final deFila = StreamController<int>();
    addTearDown(controlador.close);
    addTearDown(deFila.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EntradaDifuminada(
                child: StreamBuilder<int>(
                  stream: controlador.stream,
                  builder: (_, s) => Text('entrada ${s.data ?? '-'}'),
                ),
              ),
              FilaEntrante(
                indice: 0,
                child: StreamBuilder<int>(
                  stream: deFila.stream,
                  builder: (_, s) => Text('fila ${s.data ?? '-'}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controlador.add(7);
    deFila.add(3);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('entrada 7'), findsOneWidget);
    expect(find.text('fila 3'), findsOneWidget);
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
    expect(
      tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
      isFalse,
    );
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('las filas entran una tras otra y quedan nítidas', (
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
      final opacidad = tester.widget<Opacity>(
        find.ancestor(of: find.text('fila $i'), matching: find.byType(Opacity)),
      );
      expect(opacidad.opacity, 1);
    }
  });
}
