import 'package:academiapp_v2/features/assessment/domain/services/practica_tema_service.dart';
import 'package:academiapp_v2/features/assessment/presentation/widgets/seccion_practica_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes_practica.dart';

void main() {
  late CorreccionFalsa correccion;
  late PracticaTemaService service;

  setUp(() {
    correccion = CorreccionFalsa(const {'p1': 'a', 'p2': 'b'});
    service = PracticaTemaService(
      repositorio: RepositorioEvaluacionEnMemoria(
        evaluaciones: [evaluacion('ev')],
        lista: [
          pregunta('p1', 1, 'Primera pregunta'),
          pregunta('p2', 2, 'Segunda pregunta'),
        ],
      ),
      correccion: correccion,
    );
  });

  Future<void> abrirPractica(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeccionPracticaTema(
            service: service,
            temaId: 'algebra-02',
            versionId: 'version-1',
            tituloTema: 'Polinomios',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quiz del tema'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    await tester.tap(find.text('Empezar quiz'));
    await tester.pumpAndSettle();
  }

  testWidgets('resuelve la practica y muestra la correccion del servidor', (
    tester,
  ) async {
    await abrirPractica(tester);

    expect(find.text('Pregunta 1 de 2'), findsOneWidget);
    // Sin elegir, no se puede avanzar.
    final siguiente = find.widgetWithText(FilledButton, 'Siguiente');
    expect(tester.widget<FilledButton>(siguiente).onPressed, isNull);

    await tester.tap(find.text('Opción uno'));
    await tester.pump();
    await tester.tap(siguiente);
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 2 de 2'), findsOneWidget);
    await tester.tap(find.text('Opción uno'));
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(correccion.ultimasRespuestas, {'p1': 'a', 'p2': 'a'});
    expect(find.text('1 de 2 correctas'), findsOneWidget);
    expect(find.text('50 %'), findsOneWidget);
    expect(find.text('Explicación de p2'), findsOneWidget);
  });

  testWidgets('muestra el error del servidor sin perder las respuestas', (
    tester,
  ) async {
    correccion.errorServidor = 'Este tema todavía no está publicado.';
    await abrirPractica(tester);

    await tester.tap(find.text('Opción dos'));
    await tester.pump();
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opción dos'));
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Este tema todavía no está publicado.'), findsOneWidget);
    expect(find.text('Pregunta 2 de 2'), findsOneWidget);
  });

  testWidgets('sin practicas lo indica', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeccionPracticaTema(
            service: PracticaTemaService(
              repositorio: RepositorioEvaluacionEnMemoria(),
              correccion: CorreccionFalsa(const {}),
            ),
            temaId: 'x',
            versionId: 'version-1',
            tituloTema: 'X',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay quiz para este tema.'), findsOneWidget);
  });

  testWidgets('bloqueado hasta terminar la clase', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeccionPracticaTema(
            service: service,
            temaId: 'algebra-02',
            versionId: 'version-1',
            tituloTema: 'Polinomios',
            habilitada: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Termina la clase para activar el quiz.'), findsOneWidget);
    expect(find.text('Disponible'), findsNothing);
    final boton = find.widgetWithText(FilledButton, 'Empezar quiz');
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
  });
}
