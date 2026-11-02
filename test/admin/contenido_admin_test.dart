import 'package:academiapp_v2/admin/contenido/editor_tema_page.dart';
import 'package:academiapp_v2/admin/contenido/modelo_contenido.dart';
import 'package:academiapp_v2/admin/contenido/repositorio_contenido_admin.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const tema = Tema(
  id: 'algebra-02',
  cursoId: 'algebra',
  titulo: 'Polinomios',
  orden: 2,
);
const curso = Curso(id: 'algebra', areaId: 'mat', nombre: 'Álgebra', orden: 1);

class Repositorio implements RepositorioContenidoAdmin {
  final guardados = <Map<String, Object?>>[];

  @override
  Future<String> materialTutor(String versionId, String temaId) async =>
      'Un polinomio es…';

  @override
  Future<void> guardarTema({
    required String versionId,
    required Tema tema,
    required String titulo,
    required String? video,
    required String? separata,
    required List<String> contenidos,
    required String materialTutor,
  }) async => guardados.add({
    'titulo': titulo,
    'video': video,
    'separata': separata,
    'contenidos': contenidos,
    'tutor': materialTutor,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Generador implements GeneradorQuiz {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('material de los temas', () {
    test('reconoce enlaces de YouTube', () {
      for (final enlace in [
        'https://youtu.be/pRRaLT4H-9s',
        'https://www.youtube.com/watch?v=pRRaLT4H-9s&t=30',
        'https://m.youtube.com/shorts/pRRaLT4H-9s',
        'pRRaLT4H-9s',
      ]) {
        expect(idYoutube(enlace), 'pRRaLT4H-9s', reason: enlace);
      }
      expect(idYoutube('https://vimeo.com/123'), isNull);
      expect(idYoutube('hola'), isNull);
      expect(enlaceValido('https://sitio.pe/a.pdf'), isTrue);
      expect(enlaceValido('http://sitio.pe/a.pdf'), isFalse);
    });

    test('qué tan completo está un tema y los filtros', () {
      const vacio = MaterialTema(temaId: 't');
      const completo = MaterialTema(
        temaId: 't',
        video: 'abc',
        separata: 'https://x.pe',
        contenidos: ['a'],
        quizzes: {
          NivelQuiz.basica: QuizTema(
            NivelQuiz.basica,
            publicado: true,
            preguntas: 3,
          ),
        },
      );
      const borrador = MaterialTema(
        temaId: 't',
        video: 'abc',
        quizzes: {
          NivelQuiz.intermedia: QuizTema(
            NivelQuiz.intermedia,
            publicado: false,
            preguntas: 5,
          ),
        },
      );
      expect(vacio.completo, 0);
      expect(completo.completo, 1);
      expect(borrador.completo, 0.25);
      expect(pasaFiltro(FiltroTemas.faltaMaterial, completo, true), isFalse);
      expect(pasaFiltro(FiltroTemas.quizBorrador, borrador, true), isTrue);
      expect(pasaFiltro(FiltroTemas.sinPublicar, completo, false), isTrue);
    });

    test('ids del quiz y preguntas incompletas', () {
      final id = idEvaluacion('version-1', 'algebra-02', NivelQuiz.basica);
      expect(id, 'version-1__algebra-02__practica-basica');
      expect(idPregunta(id, 3), '${id}__p03');
      expect(
        const PreguntaPractica(
          enunciado: '',
          opciones: ['a', 'b'],
          correcta: 0,
        ).error,
        isNotNull,
      );
      expect(
        const PreguntaPractica(
          enunciado: '¿?',
          opciones: ['a', ''],
          correcta: 0,
        ).error,
        isNotNull,
      );
      expect(
        const PreguntaPractica(
          enunciado: '¿?',
          opciones: ['a', 'b'],
          correcta: -1,
        ).error,
        'Marca la respuesta correcta.',
      );
      expect(
        const PreguntaPractica(
          enunciado: '¿?',
          opciones: ['a', 'b'],
          correcta: 1,
        ).error,
        isNull,
      );
    });
  });

  testWidgets('editar tema: guarda el id del video y los contenidos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repositorio = Repositorio();
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: EditorTemaPage(
            versionId: 'version-1',
            tema: tema,
            curso: curso,
            material: const MaterialTema(
              temaId: 'algebra-02',
              contenidos: ['Grado'],
            ),
            publicado: true,
            repositorio: repositorio,
            generador: Generador(),
            onVolver: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Enlace de YouTube'),
      'https://youtu.be/pRRaLT4H-9s',
    );
    await tester.tap(find.text('Agregar'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(3), 'Valor numérico');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repositorio.guardados.single['video'], 'pRRaLT4H-9s');
    expect(repositorio.guardados.single['contenidos'], [
      'Grado',
      'Valor numérico',
    ]);
    expect(repositorio.guardados.single['tutor'], 'Un polinomio es…');
  });
}
