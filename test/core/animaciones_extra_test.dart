import 'package:academiapp_v2/core/presentation/marquesina_vertical.dart';
import 'package:academiapp_v2/core/presentation/respuesta_animada.dart';
import 'package:academiapp_v2/features/exams/domain/entities/examen.dart';
import 'package:academiapp_v2/features/exams/domain/entities/simulacro.dart';
import 'package:academiapp_v2/features/exams/presentation/pages/examenes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la marca se dibuja y termina completa', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: MarcaDibujada(correcta: true, color: Colors.green)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MarcaDibujada), findsOneWidget);
  });

  testWidgets('la marquesina pasa a la siguiente línea y se pausa al tocar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarquesinaVertical(
            cada: Duration(seconds: 1),
            lineas: [(Icons.schedule, 'Primera'), (Icons.star, 'Segunda')],
          ),
        ),
      ),
    );
    expect(find.text('Primera'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Segunda'), findsOneWidget);
    expect(find.text('Primera'), findsNothing);

    // En pausa no cambia.
    await tester.tap(find.byType(MarquesinaVertical));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Segunda'), findsOneWidget);
  });

  test('noticias de Exámenes: cierre, top 1, tu puesto y el más nuevo', () {
    final lineas = noticiasExamenes(
      estado: EstadoExamenSemanal(
        semana: 3,
        publicado: true,
        cierra: DateTime(2026, 11, 14),
      ),
      ranking: const RankingSemanal(
        titulo: 'Semana 2',
        participantes: 12,
        top: [
          PuestoRanking(
            puesto: 1,
            nombre: 'Ana Q.',
            puntaje: 95,
            correctas: 19,
            total: 20,
            tiempoUsadoSegundos: 1200,
          ),
        ],
        yo: PuestoRanking(
          puesto: 7,
          nombre: 'Luis P.',
          puntaje: 60,
          correctas: 12,
          total: 20,
          tiempoUsadoSegundos: 1500,
          soyYo: true,
        ),
      ),
      examenes: [
        ExamenPasado(
          id: 'a',
          tipo: TipoExamen.exonerados,
          fecha: DateTime(2025, 3, 1),
          titulo: 'Exonerados · 1 mar 2025',
          totalPreguntas: 50,
        ),
        ExamenPasado(
          id: 'b',
          tipo: TipoExamen.ordinario,
          fecha: DateTime(2026, 3, 22),
          titulo: 'Ordinario · 22 mar 2026',
          totalPreguntas: 100,
        ),
      ],
    );
    expect(
      [for (final (_, t) in lineas) t],
      [
        'Semana 3: cierra el viernes 13 nov',
        'Top 1 · Semana 2: Ana Q. con 95 %',
        'Tu último puesto: 7 de 12',
        'Examen pasado más reciente: Ordinario · 22 mar 2026',
      ],
    );
  });
}
