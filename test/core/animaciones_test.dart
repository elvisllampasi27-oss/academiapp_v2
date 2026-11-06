import 'package:academiapp_v2/core/presentation/animaciones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

void main() {
  test('la cascada desenfoca los primeros bloques y deja los espacios', () {
    final hijos = enCascada([
      const Text('a'),
      const SizedBox(height: 8),
      const Text('b'),
      const Text('c'),
    ], difuminados: 2);

    expect(hijos[0], isA<EntradaDifuminada>());
    expect(hijos[1], isA<SizedBox>());
    expect(hijos[2], isA<EntradaDifuminada>());
    expect(hijos[3], isA<FilaEntrante>());
  });

  testWidgets('la barra se llena hasta su valor', (tester) async {
    await tester.pumpWidget(_app(const BarraProgreso(valor: 0.6)));
    LinearProgressIndicator barra() =>
        tester.widget(find.byType(LinearProgressIndicator));
    expect(barra().value, 0);

    await tester.pumpAndSettle();
    expect(barra().value, closeTo(0.6, 0.0001));
  });

  testWidgets('el veredicto termina quieto y a tamaño normal', (tester) async {
    await tester.pumpWidget(
      _app(const IconoVeredicto(correcta: false, color: Colors.red)),
    );
    await tester.pumpAndSettle();

    final escala = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byIcon(Icons.cancel),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(escala.transform.getMaxScaleOnAxis(), closeTo(1, 0.0001));
  });

  testWidgets('la reacción se dispara al cambiar y vuelve a su lugar', (
    tester,
  ) async {
    Widget opcion(Object disparo) => _app(
      Reaccion(golpe: Golpe.sacudida, disparo: disparo, child: const Text('A')),
    );
    await tester.pumpWidget(opcion(1));
    await tester.pumpWidget(opcion(2));
    await tester.pump(const Duration(milliseconds: 60));
    final enMovimiento = tester.getTopLeft(find.text('A')).dx;

    await tester.pumpAndSettle();
    final quieto = tester.getTopLeft(find.text('A')).dx;
    expect(enMovimiento, isNot(quieto));
    expect(quieto, 0);
  });
}
