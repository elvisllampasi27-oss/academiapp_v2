import 'package:academiapp_v2/features/academic/domain/entities/area.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curriculo.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/presentation/pages/curso_detalle_page.dart';
import 'package:academiapp_v2/features/academic/presentation/pages/cursos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _curriculo = Curriculo(
  versionId: 'version-1',
  areas: [
    Area(id: 'comunicacion', nombre: 'Comunicación', orden: 1),
    Area(id: 'matematica', nombre: 'Matemática', orden: 2),
  ],
  cursos: [
    Curso(id: 'lenguaje', areaId: 'comunicacion', nombre: 'Lenguaje', orden: 2),
    Curso(id: 'algebra', areaId: 'matematica', nombre: 'Álgebra', orden: 5),
  ],
  temas: [
    Tema(id: 'lenguaje-01', cursoId: 'lenguaje', titulo: 'Signo', orden: 1),
    Tema(id: 'algebra-01', cursoId: 'algebra', titulo: 'Exponentes', orden: 1),
    Tema(id: 'algebra-02', cursoId: 'algebra', titulo: 'Polinomios', orden: 2),
    Tema(
      id: 'algebra-03',
      cursoId: 'algebra',
      titulo: 'Productos notables',
      orden: 3,
    ),
  ],
);

Future<void> _mostrar(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
}

void main() {
  testWidgets('muestra los cursos con sus temas publicados', (tester) async {
    final abiertos = <String>[];
    await _mostrar(
      tester,
      CursosPage(
        curriculo: _curriculo,
        publicados: const {'lenguaje-01', 'algebra-01', 'algebra-02'},
        onAbrirCurso: (c) => abiertos.add(c.id),
      ),
    );

    expect(find.text('Lenguaje'), findsOneWidget);
    expect(find.text('Álgebra'), findsOneWidget);
    expect(find.text('2 de 3 temas'), findsOneWidget);
    expect(find.text('1 de 1 temas'), findsOneWidget);

    await tester.tap(find.text('Álgebra'));
    expect(abiertos, ['algebra']);
  });

  testWidgets('filtra por área y busca sin tildes', (tester) async {
    await _mostrar(
      tester,
      CursosPage(
        curriculo: _curriculo,
        publicados: const {},
        onAbrirCurso: (_) {},
      ),
    );

    await tester.tap(find.text('Matemática'));
    await tester.pump();
    expect(find.text('Lenguaje'), findsNothing);
    expect(find.text('Álgebra'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.enterText(find.byType(TextField), 'polinomio');
    await tester.pump();
    expect(find.text('Álgebra'), findsOneWidget);
    expect(find.text('Lenguaje'), findsNothing);
  });

  testWidgets('los temas no publicados no se pueden abrir', (tester) async {
    final abiertos = <String>[];
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CursoDetallePage(
          curso: _curriculo.cursos.last,
          nombreArea: 'Matemática',
          temas: _curriculo.temasDe('algebra'),
          publicados: const {'algebra-01', 'algebra-02'},
          practicados: const {'algebra-01'},
          hoy: const {'algebra-02'},
          onAbrirTema: (t) => abiertos.add(t.id),
        ),
      ),
    );

    expect(find.text('Matemática · 3 temas'), findsOneWidget);
    expect(find.text('2 de 3 temas publicados'), findsOneWidget);
    expect(find.text('Practicado'), findsOneWidget);
    expect(find.text('HOY'), findsOneWidget);
    expect(find.text('Próximamente'), findsOneWidget);

    await tester.tap(find.text('Productos notables'));
    await tester.tap(find.text('Polinomios'));
    expect(abiertos, ['algebra-02']);
  });
}
