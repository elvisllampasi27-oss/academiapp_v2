import 'package:academiapp_v2/features/exams/domain/entities/simulacro.dart';
import 'package:academiapp_v2/features/exams/presentation/widgets/notas_semanales.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compara la última nota con la anterior', () {
    expect(cambioDeNota(const []), isNull);
    expect(
      cambioDeNota(const [
        NotaSemanal(semana: 1, puntaje: 60),
        NotaSemanal(semana: 2, puntaje: 70),
      ]),
      '↑ 10 puntos desde la semana anterior',
    );
    expect(
      cambioDeNota(const [
        NotaSemanal(semana: 1, puntaje: 70),
        NotaSemanal(semana: 2, puntaje: 69),
      ]),
      '↓ 1 punto desde la semana anterior',
    );
  });

  testWidgets('la gráfica se dibuja y muestra cómo le fue', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotasSemanalesCard(
            cargar: () async => const [
              NotaSemanal(semana: 1, puntaje: 55),
              NotaSemanal(semana: 2, puntaje: 70),
              NotaSemanal(semana: 3, puntaje: 85),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Tu nota semana a semana'), findsOneWidget);
    expect(find.text('↑ 15 puntos desde la semana anterior'), findsOneWidget);
    expect(find.byType(GraficoNotas), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin exámenes aún, lo explica', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotasSemanalesCard(cargar: () async => const [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Cuando des tu primer examen'), findsOneWidget);
    expect(find.byType(GraficoNotas), findsNothing);
  });
}
