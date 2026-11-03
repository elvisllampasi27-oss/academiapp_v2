import 'package:academiapp_v2/features/exams/domain/entities/simulacro.dart';
import 'package:academiapp_v2/features/exams/infrastructure/examenes_desde_mapa.dart';
import 'package:academiapp_v2/features/exams/presentation/pages/examenes_page.dart';
import 'package:academiapp_v2/features/exams/presentation/pages/ranking_semanal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_examenes.dart';

const puestoAna = PuestoRanking(
  puesto: 1,
  nombre: 'Ana Q.',
  puntaje: 90,
  correctas: 18,
  total: 20,
  tiempoUsadoSegundos: 1500,
);

void main() {
  Future<void> grande(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  test('lee el ranking del servidor; sin examen dado no hay ranking', () {
    expect(rankingDesdeMapa({'examenId': null}), isNull);
    final r = rankingDesdeMapa({
      'examenId': 'v1__s03',
      'titulo': 'Semana 3 · Ciclo 2026-II',
      'participantes': 12,
      'top': [
        {'puesto': 1, 'nombre': 'Ana Q.', 'puntaje': 90, 'soyYo': false},
      ],
      'yo': {'puesto': 7, 'nombre': 'Luis P.', 'puntaje': 55, 'soyYo': true},
    })!;
    expect(r.titulo, 'Semana 3 · Ciclo 2026-II');
    expect(r.top.single.nombre, 'Ana Q.');
    expect(r.yo!.puesto, 7);
    expect(r.yoFueraDelTop, isTrue);
  });

  testWidgets('ranking: muestra mi puesto y el top', (tester) async {
    await grande(tester);
    final servicio = ServicioExamenesFalso()
      ..rankingSemanal = const RankingSemanal(
        titulo: 'Semana 3 · Ciclo 2026-II',
        participantes: 12,
        top: [puestoAna],
        yo: PuestoRanking(
          puesto: 7,
          nombre: 'Luis P.',
          puntaje: 55,
          correctas: 11,
          total: 20,
          tiempoUsadoSegundos: 2100,
          soyYo: true,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(home: RankingSemanalPage(servicio: servicio)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Semana 3 · Ciclo 2026-II'), findsOneWidget);
    expect(find.text('12 estudiantes lo dieron'), findsOneWidget);
    expect(find.text('#7'), findsOneWidget);
    expect(find.text('Ana Q.'), findsOneWidget);
    expect(find.text('90 %'), findsOneWidget);
  });

  testWidgets('ya lo dio: no puede volver a darlo y ve su nota', (
    tester,
  ) async {
    await grande(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExamenesPage(
            repositorio: RepositorioExamenesEnMemoria(),
            servicio: ServicioExamenesFalso()
              ..estado = const EstadoExamenSemanal(
                semana: 2,
                publicado: true,
                intento: EstadoIntento.completado,
                puntaje: 85,
              ),
            hoy: DateTime(2026, 11, 9),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ya lo diste: 85 %'), findsOneWidget);
    final boton = find.widgetWithText(FilledButton, 'Ya lo diste');
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
  });

  testWidgets('ranking: sin examen dado todavía', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RankingSemanalPage(servicio: ServicioExamenesFalso())),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Cuando des tu primer examen semanal, aquí verás tu puesto.'),
      findsOneWidget,
    );
  });

  testWidgets('el examen semanal pide confirmar (un solo intento)', (
    tester,
  ) async {
    await grande(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExamenesPage(
            repositorio: RepositorioExamenesEnMemoria(),
            servicio: ServicioExamenesFalso()
              ..estado = EstadoExamenSemanal(
                semana: 1,
                titulo: 'Semana 1 · Ciclo 2026-II',
                publicado: true,
                totalPreguntas: 20,
                cierra: DateTime(2026, 11, 14),
              ),
            hoy: DateTime(2026, 11, 9),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Examen semanal'), findsOneWidget);
    expect(
      find.textContaining('Tienes hasta el viernes 13 nov.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Empezar el examen semanal?'), findsOneWidget);

    await tester.tap(find.text('Todavía no'));
    await tester.pumpAndSettle();
    expect(find.text('¿Empezar el examen semanal?'), findsNothing);
  });
}
