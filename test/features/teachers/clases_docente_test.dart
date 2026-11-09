import 'package:academiapp_v2/core/presentation/video/id_youtube.dart';
import 'package:academiapp_v2/core/presentation/video/reproductor_clase.dart';
import 'package:academiapp_v2/features/academic/domain/entities/area.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curriculo.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/teachers/domain/clase_docente.dart';
import 'package:academiapp_v2/features/teachers/infrastructure/repositorio_clases_docente_firestore.dart';
import 'package:academiapp_v2/features/teachers/presentation/clases_del_docente.dart';
import 'package:academiapp_v2/features/teachers/presentation/corazones_clases.dart';
import 'package:academiapp_v2/features/teachers/presentation/seccion_clases_docentes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ClaseDocente _clase(String id, String titulo, int corazones, DateTime fecha) =>
    ClaseDocente(
      id: id,
      docenteUid: 'profe',
      docenteNombre: 'Prof. Ana Quispe',
      temaId: 'his-03',
      temaTitulo: 'Los incas',
      cursoNombre: 'Historia del Perú',
      titulo: titulo,
      videoId: 'pRRaLT4H-9s',
      estado: EstadoClaseDocente.aprobada,
      corazones: corazones,
      creadaEn: fecha,
    );

class _Repositorio implements RepositorioClasesDocente {
  final List<ClaseDocente> clases;
  final Set<String> mios;
  bool falla = false;
  final acciones = <String>[];
  final enviadas = <Map<String, Object?>>[];

  _Repositorio(this.clases, {this.mios = const {}});

  @override
  Future<List<ClaseDocente>> delTema(String temaId) async =>
      ordenarPorCorazones(clases);

  @override
  Future<Set<String>> conMiCorazon(String uid, List<String> claseIds) async =>
      mios;

  @override
  Future<void> darCorazon(String claseId, String uid) async {
    if (falla) throw StateError('sin red');
    acciones.add('dar $claseId');
  }

  @override
  Future<void> quitarCorazon(String claseId, String uid) async {
    if (falla) throw StateError('sin red');
    acciones.add('quitar $claseId');
  }

  @override
  Future<List<ClaseDocente>> mias(String docenteUid) async => clases;

  @override
  Future<List<ClaseDocente>> deDocente(String docenteUid) async =>
      ordenarPorCorazones(clases);

  @override
  Future<void> enviar({
    required String docenteUid,
    required String docenteNombre,
    required String temaId,
    required String temaTitulo,
    required String cursoNombre,
    required String titulo,
    required String videoId,
  }) async => enviadas.add({
    'temaId': temaId,
    'temaTitulo': temaTitulo,
    'cursoNombre': cursoNombre,
    'titulo': titulo,
    'videoId': videoId,
  });
}

Widget _reproductorFalso({
  required String videoId,
  required double inicio,
  required ControlClase control,
  required AlAvanzarClase alAvanzar,
}) => Text('video $videoId');

void main() {
  group('reglas de la clase', () {
    test('qué falta para enviarla', () {
      expect(
        errorClaseDocente(temaId: null, titulo: 'Incas', enlace: ''),
        contains('tema'),
      );
      expect(
        errorClaseDocente(temaId: 't', titulo: 'Hi', enlace: ''),
        contains('título'),
      );
      expect(
        errorClaseDocente(
          temaId: 't',
          titulo: 'Incas',
          enlace: 'https://vimeo.com/1',
        ),
        contains('YouTube'),
      );
      expect(
        errorClaseDocente(
          temaId: 't',
          titulo: 'Incas',
          enlace: 'https://youtu.be/pRRaLT4H-9s',
        ),
        isNull,
      );
      expect(
        idVideoYoutube('https://www.youtube.com/watch?v=pRRaLT4H-9s&t=3'),
        'pRRaLT4H-9s',
      );
    });

    test('las más queridas primero; a igual cantidad, la más nueva', () {
      final orden = ordenarPorCorazones([
        _clase('a', 'A', 2, DateTime(2026, 1)),
        _clase('b', 'B', 9, DateTime(2026, 1)),
        _clase('c', 'C', 2, DateTime(2026, 3)),
      ]);
      expect([for (final c in orden) c.id], ['b', 'c', 'a']);
      expect(cantidadCorta(999), '999');
      expect(cantidadCorta(1000), '1 mil');
      expect(cantidadCorta(1240), '1.2 mil');
    });

    test('se lee de Firestore', () {
      final c = claseDesdeMapa('c1', {
        'docenteUid': 'profe',
        'docenteNombre': 'Ana',
        'temaId': 'his-03',
        'titulo': 'Incas',
        'videoId': 'pRRaLT4H-9s',
        'estado': 'aprobada',
        'corazones': 4,
        'creadaEn': Timestamp.fromDate(DateTime(2026, 11, 1)),
      })!;
      expect(c.corazones, 4);
      expect(c.miniatura, contains('pRRaLT4H-9s'));
      expect(claseDesdeMapa('c1', {'estado': 'aprobada'}), isNull);
    });

    test('el corazón cambia al instante y vuelve si falla', () async {
      final repositorio = _Repositorio([]);
      final corazones = CorazonesClases(
        repositorio: repositorio,
        uid: 'alumno',
        clases: [_clase('a', 'A', 3, DateTime(2026))],
      );
      expect(await corazones.alternar('a'), isTrue);
      expect((corazones.dado('a'), corazones.cantidad('a')), (true, 4));

      repositorio.falla = true;
      expect(await corazones.alternar('a'), isFalse);
      expect((corazones.dado('a'), corazones.cantidad('a')), (true, 4));
      expect(repositorio.acciones, ['dar a']);
    });
  });

  group('en el tema', () {
    Future<List<ClaseDocente>> montar(
      WidgetTester tester,
      _Repositorio repositorio,
    ) async {
      final reportadas = <ClaseDocente>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SeccionClasesDocentes(
                repositorio: repositorio,
                temaId: 'his-03',
                uid: 'alumno',
                onReportar: reportadas.add,
                reproductor: _reproductorFalso,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return reportadas;
    }

    testWidgets('sin clases no ocupa lugar', (tester) async {
      await montar(tester, _Repositorio([]));
      expect(find.text('Clases de docentes'), findsNothing);
    });

    testWidgets('corazones, abrir la clase y reportarla', (tester) async {
      final repositorio = _Repositorio(
        [
          _clase('a', 'Los incas en 10 minutos', 2, DateTime(2026, 1)),
          _clase('b', 'Pachacútec', 7, DateTime(2026, 1)),
        ],
        mios: {'b'},
      );
      final reportadas = await montar(tester, repositorio);

      expect(find.text('Clases de docentes'), findsOneWidget);
      // La más querida primero, con el corazón ya dado.
      expect(
        tester.getTopLeft(find.text('Pachacútec')).dy,
        lessThan(tester.getTopLeft(find.text('Los incas en 10 minutos')).dy),
      );
      expect(find.text('7'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
      expect(repositorio.acciones, ['dar a']);

      // Sin red: vuelve como estaba y avisa.
      repositorio.falla = true;
      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      expect(find.text('No se pudo guardar tu corazón.'), findsOneWidget);
      repositorio.falla = false;

      await tester.tap(find.text('Pachacútec'));
      await tester.pumpAndSettle();
      expect(find.text('video pRRaLT4H-9s'), findsOneWidget);
      expect(find.text('Prof. Ana Quispe'), findsOneWidget);

      await tester.tap(find.byTooltip('Reportar esta clase'));
      await tester.pump();
      expect(reportadas.single.id, 'b');
    });
  });

  testWidgets('el docente elige curso y tema y envía su clase', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repositorio = _Repositorio([]);
    const curriculo = Curriculo(
      versionId: 'v1',
      areas: [Area(id: 'letras', nombre: 'Letras', orden: 1)],
      cursos: [
        Curso(id: 'his', areaId: 'letras', nombre: 'Historia', orden: 1),
      ],
      temas: [
        Tema(id: 'his-01', cursoId: 'his', titulo: 'Los incas', orden: 1),
        Tema(id: 'his-02', cursoId: 'his', titulo: 'La colonia', orden: 2),
      ],
    );
    bool? enviada;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              enviada = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EnviarClaseDocentePage(
                    uid: 'profe',
                    nombre: 'Ana',
                    curriculo: curriculo,
                    repositorio: repositorio,
                  ),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enviar para revisión'));
    await tester.pump();
    expect(find.text('Elige el curso y el tema de tu clase.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<Curso>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historia').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Tema>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. La colonia').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Título de la clase'),
      'La colonia en 15 minutos',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Enlace de YouTube'),
      'https://youtu.be/pRRaLT4H-9s',
    );
    await tester.tap(find.text('Enviar para revisión'));
    await tester.pumpAndSettle();

    expect(repositorio.enviadas.single, {
      'temaId': 'his-02',
      'temaTitulo': 'La colonia',
      'cursoNombre': 'Historia',
      'titulo': 'La colonia en 15 minutos',
      'videoId': 'pRRaLT4H-9s',
    });
    expect(enviada, isTrue);
  });
}
