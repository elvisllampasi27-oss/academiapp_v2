import 'package:academiapp_v2/core/presentation/puma_tutor.dart';
import 'package:academiapp_v2/core/presentation/voz_puma.dart';
import 'package:academiapp_v2/features/assessment/presentation/widgets/mensaje_puma.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _rutaMostrada(WidgetTester tester) {
  final imagen = tester.widget<Image>(find.byType(Image).last);
  return (imagen.image as AssetImage).assetName;
}

void main() {
  test('el ánimo tiene su propio dibujo (ni el contento ni el serio)', () {
    final animo = PumaTutor.rutaDe(GestoPuma.animo);
    expect(animo, endsWith('animo.webp'));
    expect(animo, isNot(PumaTutor.rutaDe(GestoPuma.contento)));
    expect(animo, isNot(PumaTutor.rutaDe(GestoPuma.serio)));
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

  testWidgets('hablando: se queda con el dibujo atento y no parpadea', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PumaTutor(gesto: GestoPuma.contento, hablando: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Habla sobre el atento (la mandíbula se recorta de él), sin cambiar de
    // dibujo en cada palabra.
    expect(_rutaMostrada(tester), PumaTutor.rutaDe(GestoPuma.atento));

    await tester.pump(const Duration(seconds: 6));
    expect(_rutaMostrada(tester), PumaTutor.rutaDe(GestoPuma.atento));
  });

  testWidgets('cada palabra abre la boca y luego la cierra sola', (
    tester,
  ) async {
    Widget puma(int silabas) => MaterialApp(
      home: Scaffold(body: PumaTutor(hablando: true, silabas: silabas)),
    );
    await tester.pumpWidget(puma(0));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(puma(1));
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.hasRunningAnimations, isTrue); // abriendo

    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse); // ya cerrada
  });

  group('voz en español', () {
    test('prefiere el acento peruano o latino', () {
      expect(
        VozPumaDispositivo.elegirIdioma(['en-US', 'es-ES', 'es-US']),
        'es-US',
      );
      expect(VozPumaDispositivo.elegirIdioma(['es_PE', 'es-ES']), 'es_PE');
    });

    test('si no hay acento preferido, cualquier español', () {
      expect(VozPumaDispositivo.elegirIdioma(['en-GB', 'es-AR']), 'es-AR');
    });

    test('sin español no hay voz (queda solo el texto)', () {
      expect(VozPumaDispositivo.elegirIdioma(['en-US', 'pt-BR']), isNull);
    });
  });

  group('voz de hombre', () {
    test('elige la voz masculina aunque haya otras mejores en acento', () {
      final voz = VozPumaDispositivo.elegirVoz([
        {
          'name': 'Microsoft Camila Online (Natural) - Spanish (Peru)',
          'locale': 'es-PE',
        },
        {
          'name': 'Microsoft Alex Online (Natural) - Spanish (Peru)',
          'locale': 'es-PE',
        },
        {'name': 'Microsoft Raul - Spanish (Mexico)', 'locale': 'es-MX'},
      ]);
      expect(voz?.nombre, 'Microsoft Alex Online (Natural) - Spanish (Peru)');
      expect(voz?.esHombre, isTrue);
    });

    test('usa el género cuando el sistema lo dice (iOS)', () {
      final voz = VozPumaDispositivo.elegirVoz([
        {'name': 'Paulina', 'locale': 'es-MX', 'gender': 'female'},
        {'name': 'Desconocida', 'locale': 'es-ES', 'gender': 'male'},
      ]);
      expect(voz?.nombre, 'Desconocida');
    });

    test('"female" no se confunde con "male"', () {
      final voz = VozPumaDispositivo.elegirVoz([
        {'name': 'es-us-female-1', 'locale': 'es-US'},
      ]);
      expect(voz?.esHombre, isFalse);
    });

    test('sin voces en español no elige ninguna', () {
      expect(
        VozPumaDispositivo.elegirVoz([
          {'name': 'Microsoft David - English', 'locale': 'en-US'},
        ]),
        isNull,
      );
    });
  });
}
