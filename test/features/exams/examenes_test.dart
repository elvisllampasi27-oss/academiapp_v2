import 'package:academiapp_v2/features/exams/domain/entities/examen.dart';
import 'package:academiapp_v2/features/exams/domain/entities/simulacro.dart';
import 'package:academiapp_v2/features/exams/domain/repositories/servicio_examenes.dart';
import 'package:academiapp_v2/features/exams/infrastructure/examenes_desde_mapa.dart';
import 'package:academiapp_v2/features/exams/infrastructure/servicio_examenes_cloud_functions.dart';
import 'package:academiapp_v2/features/exams/presentation/pages/examenes_page.dart';
import 'package:academiapp_v2/features/exams/presentation/pages/practica_examen_page.dart';
import 'package:academiapp_v2/features/exams/presentation/pages/simulacro_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes_examenes.dart';

void main() {
  final domingo = DateTime(2026, 11, 1);
  final lunes = DateTime(2026, 11, 2);

  Future<void> grande(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  group('datos', () {
    test('el examen tipo admision es solo sabado y domingo', () {
      expect(esDiaDeSimulacro(DateTime(2026, 10, 31)), isTrue);
      expect(esDiaDeSimulacro(domingo), isTrue);
      expect(esDiaDeSimulacro(lunes), isFalse);
    });

    test('lee examenes, preguntas y resultados del servidor', () {
      final examen = examenDesdeMapa('exonerados-2025-11-16', {
        'tipo': 'exonerados',
        'fecha': '2025-11-16',
        'titulo': 'Exonerados · 16 nov 2025',
        'totalPreguntas': 98,
        'secciones': [
          {'nombre': 'Comunicación', 'total': 18},
        ],
      })!;
      expect(examen.tipo, TipoExamen.exonerados);
      expect(examen.secciones.single.total, 18);
      expect(examenDesdeMapa('x', {'tipo': 'otro', 'fecha': '2025'}), isNull);

      final pregunta = preguntaDesdeMapa('p1', {
        'numero': 3,
        'seccion': 'Ciencias',
        'enunciado': '¿?',
        'opciones': [
          {'id': 'a', 'texto': 'uno'},
          {'id': 'b', 'texto': 'dos'},
        ],
        'imagen': null,
      });
      expect(pregunta.letraDe('b'), 'B');
      expect(pregunta.imagen, isNull);

      final resultado = resultadoDesdeMapa({
        'correctas': 1,
        'total': 2,
        'puntaje': 50,
        'tiempoUsadoSegundos': 90,
        'porSeccion': [
          {'nombre': 'Ciencias', 'correctas': 1, 'total': 2},
        ],
        'detalle': [
          {
            'preguntaId': 'p1',
            'opcionElegidaId': null,
            'opcionCorrectaId': 'a',
            'esCorrecta': false,
          },
        ],
      });
      expect(resultado.porSeccion.single.nombre, 'Ciencias');
      expect(resultado.detalle.single.opcionElegidaId, isNull);
    });

    test('mensajes de error del servidor', () {
      expect(
        mensajeErrorExamen(
          'failed-precondition',
          'El examen tipo admisión se da sábados y domingos.',
        ),
        'El examen tipo admisión se da sábados y domingos.',
      );
      expect(
        mensajeErrorExamen('internal', 'stack'),
        'Ocurrió un error. Inténtalo de nuevo.',
      );
    });
  });

  testWidgets(
    'la pestana muestra los pasados y bloquea el simulacro entre semana',
    (tester) async {
      await grande(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamenesPage(
              repositorio: RepositorioExamenesEnMemoria(
                examenes: [examenExonerados],
              ),
              servicio: ServicioExamenesFalso(),
              hoy: lunes,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sin Ordinarios cargados abre directo en Exonerados.
      expect(find.text('Exonerados · 16 nov 2025'), findsOneWidget);
      final boton = find.widgetWithText(FilledButton, 'Disponible el sábado');
      expect(tester.widget<FilledButton>(boton).onPressed, isNull);

      await tester.tap(find.text('Ordinario'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aún no hay exámenes Ordinario cargados.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('examen pasado: responde y ve la correcta con la solucion', (
    tester,
  ) async {
    await grande(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticaExamenPage(
          examen: examenExonerados,
          repositorio: RepositorioExamenesEnMemoria(
            lista: [preguntaExamen('p1'), preguntaExamen('p2')],
          ),
          servicio: ServicioExamenesFalso(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enunciado p1'), findsOneWidget);
    await tester.tap(find.text('Opción uno'));
    await tester.pumpAndSettle();

    expect(find.text('La correcta es la B'), findsOneWidget);
    expect(find.text('Solución de p1'), findsOneWidget);

    await tester.tap(find.text('Siguiente pregunta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opción dos'));
    await tester.pumpAndSettle();
    expect(find.text('¡Correcto! Es la B'), findsOneWidget);

    await tester.tap(find.text('Ver resultado'));
    await tester.pumpAndSettle();
    expect(find.text('Acertaste 1 de 2.'), findsOneWidget);
  });

  testWidgets(
    'simulacro: responde sin ver la correcta y al terminar ve el resultado',
    (tester) async {
      await grande(tester);
      final servicio = ServicioExamenesFalso(
        preguntasSimulacro: [
          preguntaExamen('p1', seccion: 'Comunicación'),
          preguntaExamen('p2'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SimulacroPage(
            servicio: servicio,
            ahora: () => DateTime(2026, 11, 1, 10, 0),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('40:00'), findsOneWidget);
      expect(find.text('Pregunta 1 de 2 · Comunicación'), findsOneWidget);

      await tester.tap(find.text('Opción dos'));
      await tester.pump();
      // Sin pistas: no dice si acertó.
      expect(find.textContaining('correcta'), findsNothing);

      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      await tester.tap(find.text('Terminar'));
      await tester.pump();
      expect(find.text('Te falta 1 pregunta por responder.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Terminar').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(servicio.enviadas, {'p1': 'b'});
      expect(find.text('1 de 2 correctas'), findsOneWidget);
      expect(find.text('50 % · tiempo usado 12:34'), findsOneWidget);

      await tester.tap(find.text('Revisar mis respuestas'));
      await tester.pump();
      expect(find.text('No respondiste.'), findsOneWidget);
    },
  );

  testWidgets('simulacro fuera de fecha muestra el aviso del servidor', (
    tester,
  ) async {
    final servicio = ServicioExamenesFalso()
      ..errorAlIniciar = const ErrorExamen(
        'El examen tipo admisión se da sábados y domingos.',
      );

    await tester.pumpWidget(
      MaterialApp(home: SimulacroPage(servicio: servicio)),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('El examen tipo admisión se da sábados y domingos.'),
      findsOneWidget,
    );
  });
}
