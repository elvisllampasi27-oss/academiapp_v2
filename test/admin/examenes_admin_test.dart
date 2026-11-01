import 'package:academiapp_v2/admin/examenes/examenes_admin_page.dart';
import 'package:academiapp_v2/admin/examenes/modelo_examen_admin.dart';
import 'package:academiapp_v2/admin/examenes/repositorio_examenes_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RepositorioFalso implements RepositorioExamenesAdmin {
  final List<PreguntaAdmin> lista;
  final guardadas = <PreguntaAdmin>[];
  List<PreguntaAdmin>? ultimasTodas;

  RepositorioFalso(this.lista);

  @override
  Future<List<ExamenAdmin>> examenes() async => const [
    ExamenAdmin(
      id: 'exonerados-2025-11-16',
      titulo: 'Exonerados · 16 nov 2025',
      tipo: 'exonerados',
      fecha: '2025-11-16',
      estado: 'publicado',
      totalPreguntas: 1,
    ),
  ];

  @override
  Future<List<PreguntaAdmin>> preguntas(String examenId) async => lista;

  @override
  Future<void> guardar(
    PreguntaAdmin pregunta, {
    PreguntaAdmin? anterior,
    required List<PreguntaAdmin> todas,
  }) async {
    guardadas.add(pregunta);
    ultimasTodas = todas;
  }

  @override
  Future<void> cambiarEstado(
    String examenId, {
    required bool publicado,
  }) async {}
}

const pregunta = PreguntaAdmin(
  id: 'exonerados-2025-11-16__p001',
  examenId: 'exonerados-2025-11-16',
  numero: 1,
  seccion: 'Comunicación',
  enunciado: '¿Cuál es el antónimo de la palabra subrayada?',
  opciones: [
    'lesivos',
    'recomendados',
    'beneficiosos',
    'letales',
    'perjudiciales',
  ],
  correcta: 2,
);

void main() {
  group('modelo', () {
    test('separa la pregunta publica de la clave', () {
      final publica = pregunta.datosPregunta();
      final clave = pregunta.datosClave();

      expect(publica.containsKey('opcionCorrectaId'), isFalse);
      expect((publica['opciones'] as List).length, 5);
      expect(clave['opcionCorrectaId'], 'c');
      expect(clave['solucion'], isNull);
    });

    test('valida antes de guardar', () {
      expect(pregunta.validar(), isNull);
      expect(pregunta.copiar(enunciado: ' ').validar(), 'Falta el enunciado.');
      expect(
        pregunta.copiar(correcta: -1).validar(),
        'Marca cuál es la alternativa correcta.',
      );
      expect(
        pregunta.copiar(imagen: 'http://inseguro.pe/x.jpg').validar(),
        'Las imágenes deben ser enlaces https.',
      );
    });

    test('lee pregunta y clave y cuenta secciones activas', () {
      final p = preguntaAdminDesdeMapas(
        'x',
        {
          'examenId': 'e',
          'numero': 4,
          'seccion': 'Ciencias',
          'enunciado': 'E',
          'opciones': [
            {'id': 'a', 'texto': 'uno'},
            {'id': 'b', 'texto': 'dos'},
          ],
          'imagen': null,
          'activa': true,
        },
        {'opcionCorrectaId': 'b', 'solucion': 'Porque sí'},
      );

      expect(p.correcta, 1);
      expect(p.tieneSolucion, isTrue);
      expect(PreguntaAdmin.idPara('e', 7), 'e__p007');
      expect(seccionesDe([p, p.copiar(activa: false)]), [
        {'nombre': 'Ciencias', 'total': 1},
      ]);
    });
  });

  testWidgets('edita una pregunta y guarda la correccion', (tester) async {
    tester.view.physicalSize = const Size(2800, 1800);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);

    final repo = RepositorioFalso([pregunta]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExamenesAdminPage(repositorio: repo)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exonerados · 16 nov 2025'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#1 · Comunicación'));
    await tester.pumpAndSettle();

    // Se corrige el enunciado al que le faltaba la oración.
    await tester.enterText(
      find.widgetWithText(
        TextField,
        '¿Cuál es el antónimo de la palabra subrayada?',
      ),
      'Antónimo de NOCIVOS en: "Los alimentos nocivos dañan la salud".',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repo.guardadas.single.enunciado, startsWith('Antónimo de NOCIVOS'));
    expect(repo.guardadas.single.correcta, 2);
    expect(find.text('Pregunta 1 guardada.'), findsOneWidget);
  });

  testWidgets('una pregunta nueva no se guarda sin marcar la correcta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2800, 1800);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);

    final repo = RepositorioFalso([pregunta]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExamenesAdminPage(repositorio: repo)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exonerados · 16 nov 2025'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva pregunta #2'), findsOneWidget);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Falta el enunciado.'), findsOneWidget);
    expect(repo.guardadas, isEmpty);
  });
}
