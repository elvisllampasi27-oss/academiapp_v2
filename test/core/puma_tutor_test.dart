import 'package:academiapp_v2/core/presentation/puma_tutor.dart';
import 'package:academiapp_v2/features/assessment/presentation/widgets/mensaje_puma.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _rutaMostrada(WidgetTester tester) {
  final imagen = tester.widget<Image>(find.byType(Image).last);
  return (imagen.image as AssetImage).assetName;
}

void main() {
  test('el ánimo nunca usa el dibujo sonriendo', () {
    expect(
      PumaTutor.rutaDe(GestoPuma.animo),
      PumaTutor.rutaDe(GestoPuma.serio),
    );
    expect(
      PumaTutor.rutaDe(GestoPuma.animo),
      isNot(PumaTutor.rutaDe(GestoPuma.contento)),
    );
  });

  group('mensaje del puma', () {
    test('todo bien: contento', () {
      final m = mensajeDelPuma(correctas: 5, total: 5, tema: 'Polinomios');
      expect(m.gesto, GestoPuma.contento);
      expect(m.texto, contains('Polinomios'));
    });

    test('casi todo: contento y señala la que falló', () {
      final m = mensajeDelPuma(
        correctas: 4,
        total: 5,
        tema: 'Polinomios',
        primeraFallada: 3,
      );
      expect(m.gesto, GestoPuma.contento);
      expect(m.texto, contains('la que fallaste'));
      expect(m.texto, contains('pregunta 3'));
    });

    test('la mitad: atento', () {
      final m = mensajeDelPuma(correctas: 2, total: 4, tema: 'x');
      expect(m.gesto, GestoPuma.atento);
      expect(m.texto, contains('las 2 que fallaste'));
    });

    test('pocas: ánimo, sin burlarse', () {
      final m = mensajeDelPuma(correctas: 0, total: 4, tema: 'x');
      expect(m.gesto, GestoPuma.animo);
      expect(m.texto, startsWith('Tranquilo'));
    });
  });

  testWidgets('atento parpadea un instante y vuelve', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PumaTutor())),
    );
    expect(_rutaMostrada(tester), PumaTutor.rutaDe(GestoPuma.atento));

    await tester.pump(const Duration(seconds: 5));
    expect(_rutaMostrada(tester), endsWith('parpadeo.webp'));

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(_rutaMostrada(tester), PumaTutor.rutaDe(GestoPuma.atento));
  });

  testWidgets('con otro gesto no parpadea', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PumaTutor(gesto: GestoPuma.contento)),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(_rutaMostrada(tester), PumaTutor.rutaDe(GestoPuma.contento));
  });
}
