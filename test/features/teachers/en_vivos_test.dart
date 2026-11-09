import 'package:academiapp_v2/features/teachers/domain/clase_docente.dart';
import 'package:academiapp_v2/features/teachers/domain/en_vivo.dart';
import 'package:academiapp_v2/features/teachers/domain/solicitud_docente.dart';
import 'package:academiapp_v2/features/teachers/infrastructure/repositorio_en_vivos_firestore.dart';
import 'package:academiapp_v2/features/teachers/presentation/en_vivos.dart';
import 'package:academiapp_v2/features/teachers/presentation/perfil_docente_page.dart';
import 'package:academiapp_v2/features/teachers/presentation/programar_en_vivo_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EnVivo _enVivo(
  String id,
  DateTime inicio, {
  int minutos = 60,
  PlataformaEnVivo plataforma = PlataformaEnVivo.meet,
}) => EnVivo(
  id: id,
  docenteUid: 'profe',
  docenteNombre: 'Ana Quispe',
  titulo: 'Repaso de los incas',
  plataforma: plataforma,
  enlace: 'https://meet.google.com/abc-defg-hij',
  inicio: inicio,
  fin: inicio.add(Duration(minutes: minutos)),
  estado: EstadoEnVivo.aprobado,
  cursoNombre: 'Historia',
);

class _Repositorio implements RepositorioEnVivos {
  final List<EnVivo> lista;
  final programados = <Map<String, Object?>>[];

  _Repositorio(this.lista);

  @override
  Future<List<EnVivo>> vigentes() async => lista;

  @override
  Future<List<EnVivo>> delDocente(String docenteUid) async => lista;

  @override
  Future<List<EnVivo>> mios(String docenteUid) async => lista;

  @override
  Future<void> programar({
    required String docenteUid,
    required String docenteNombre,
    required String titulo,
    required PlataformaEnVivo plataforma,
    required String enlace,
    required DateTime inicio,
    required int duracionMinutos,
    String? cursoNombre,
  }) async => programados.add({
    'titulo': titulo,
    'plataforma': plataforma,
    'enlace': enlace,
    'inicio': inicio,
    'duracion': duracionMinutos,
  });

  @override
  Future<void> cancelar(EnVivo enVivo) async {}
}

class _Docentes implements RepositorioDocentes {
  @override
  Future<PerfilDocente?> perfil(String uid) async => const PerfilDocente(
    uid: 'profe',
    nombre: 'Ana Quispe',
    cursos: 'Historia del Perú',
    enlaces: ['https://www.youtube.com/@ana', 'https://www.tiktok.com/@ana'],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Clases implements RepositorioClasesDocente {
  @override
  Future<List<ClaseDocente>> deDocente(String docenteUid) async => [
    ClaseDocente(
      id: 'c1',
      docenteUid: 'profe',
      docenteNombre: 'Ana Quispe',
      temaId: 'his-03',
      temaTitulo: 'Los incas',
      cursoNombre: 'Historia',
      titulo: 'Pachacútec',
      videoId: 'pRRaLT4H-9s',
      estado: EstadoClaseDocente.aprobada,
      corazones: 4,
      creadaEn: DateTime(2026, 11, 1),
    ),
  ];

  @override
  Future<Set<String>> conMiCorazon(String uid, List<String> claseIds) async =>
      {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final siete = DateTime(2026, 11, 8, 19);

  group('reglas del en vivo', () {
    test('próximo, en vivo y terminado; se puede unir 10 min antes', () {
      final e = _enVivo('a', siete);
      expect(e.momento(DateTime(2026, 11, 8, 18)), MomentoEnVivo.proximo);
      expect(e.momento(DateTime(2026, 11, 8, 19, 30)), MomentoEnVivo.enVivo);
      expect(e.momento(DateTime(2026, 11, 8, 20)), MomentoEnVivo.terminado);
      expect(e.sePuedeUnir(DateTime(2026, 11, 8, 18, 49)), isFalse);
      expect(e.sePuedeUnir(DateTime(2026, 11, 8, 18, 51)), isTrue);
    });

    test('en vivo primero, luego el más cercano; sin terminados', () {
      final ahora = DateTime(2026, 11, 8, 19, 30);
      final orden = paraMostrar([
        _enVivo('lejos', DateTime(2026, 11, 10, 19)),
        _enVivo('terminado', DateTime(2026, 11, 8, 17)),
        _enVivo('cerca', DateTime(2026, 11, 8, 21)),
        _enVivo('ahora', siete),
      ], ahora);
      expect([for (final e in orden) e.id], ['ahora', 'cerca', 'lejos']);
    });

    test('cuenta regresiva', () {
      expect(cuentaRegresiva(const Duration(seconds: 9)), '00:00:09');
      expect(
        cuentaRegresiva(const Duration(hours: 2, minutes: 14, seconds: 3)),
        '02:14:03',
      );
      expect(
        cuentaRegresiva(const Duration(days: 3, hours: 1, seconds: 1)),
        '3 d 01:00:01',
      );
      expect(cuentaRegresiva(const Duration(seconds: -5)), '00:00:00');
    });

    test('qué falta para programarlo', () {
      final ahora = DateTime(2026, 11, 8, 10);
      String? error({
        String titulo = 'Repaso',
        PlataformaEnVivo plataforma = PlataformaEnVivo.tiktok,
        String enlace = 'https://www.tiktok.com/@ana/live',
        DateTime? inicio,
      }) => errorEnVivo(
        titulo: titulo,
        plataforma: plataforma,
        enlace: enlace,
        inicio: inicio ?? siete,
        ahora: ahora,
      );

      expect(error(), isNull);
      expect(error(titulo: 'Hi'), contains('título'));
      expect(error(enlace: 'tiktok.com/@ana'), contains('https://'));
      expect(error(plataforma: PlataformaEnVivo.meet), contains('Google Meet'));
      expect(
        error(plataforma: PlataformaEnVivo.otra, enlace: 'https://zoom.us/j/1'),
        isNull,
      );
      expect(error(inicio: DateTime(2026, 11, 8, 9)), contains('no pasó'));
      expect(error(inicio: DateTime(2027)), contains('días'));
    });

    test('se lee de Firestore', () {
      final e = enVivoDesdeMapa('v1', {
        'docenteUid': 'profe',
        'docenteNombre': 'Ana',
        'titulo': 'Repaso',
        'plataforma': 'tiktok',
        'enlace': 'https://www.tiktok.com/@ana/live',
        'inicio': Timestamp.fromDate(siete),
        'fin': Timestamp.fromDate(siete.add(const Duration(hours: 1))),
        'estado': 'aprobado',
        'cursoNombre': '',
      })!;
      expect(e.plataforma, PlataformaEnVivo.tiktok);
      expect(e.cursoNombre, isNull);
      expect(enVivoDesdeMapa('v1', {'plataforma': 'tiktok'}), isNull);
    });
  });

  testWidgets('en Inicio: cuenta regresiva, en vivo y desaparece', (
    tester,
  ) async {
    var reloj = DateTime(2026, 11, 8, 18, 49, 50);
    final abiertos = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeccionEnVivos(
              repositorio: _Repositorio([_enVivo('a', siete)]),
              ahora: () => reloj,
              abrirEnlace: (uri) async {
                abiertos.add(uri);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Repaso de los incas'), findsOneWidget);
    expect(find.text('Empieza en'), findsOneWidget);
    expect(find.text('00:10:10'), findsOneWidget);
    expect(find.text('Unirme'), findsNothing);

    // Faltando menos de 10 minutos ya se puede entrar.
    reloj = DateTime(2026, 11, 8, 18, 50, 30);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:09:30'), findsOneWidget);
    expect(find.text('Unirme'), findsOneWidget);

    reloj = DateTime(2026, 11, 8, 19, 0, 5);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('● EN VIVO'), findsOneWidget);
    expect(find.text('Empieza en'), findsNothing);
    await tester.tap(find.text('Unirme'));
    await tester.pump();
    expect(abiertos.single.host, 'meet.google.com');

    reloj = DateTime(2026, 11, 8, 20, 0, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Repaso de los incas'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el docente programa su en vivo', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repositorio = _Repositorio([]);
    await tester.pumpWidget(
      MaterialApp(
        home: ProgramarEnVivoPage(
          uid: 'profe',
          nombre: 'Ana',
          repositorio: repositorio,
          ahora: () => DateTime(2026, 11, 8, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Repaso de los incas',
    );
    await tester.tap(find.text('Google Meet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tú admites a cada persona'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enlace del en vivo'),
      'https://www.tiktok.com/@ana/live',
    );
    await tester.tap(find.text('Enviar para revisión'));
    await tester.pump();
    expect(find.text('Ese enlace no es de Google Meet.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Enlace del en vivo'),
      'https://meet.google.com/abc-defg-hij',
    );
    await tester.tap(find.text('Enviar para revisión'));
    await tester.pumpAndSettle();

    // Por defecto: mañana a las 7:00 p. m., una hora.
    expect(repositorio.programados.single, {
      'titulo': 'Repaso de los incas',
      'plataforma': PlataformaEnVivo.meet,
      'enlace': 'https://meet.google.com/abc-defg-hij',
      'inicio': DateTime(2026, 11, 9, 19),
      'duracion': 60,
    });
  });

  testWidgets('la página del docente: redes, en vivos y clases', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final abiertos = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PerfilDocentePage(
          docenteUid: 'profe',
          nombre: 'Ana',
          uid: 'alumno',
          docentes: _Docentes(),
          clases: _Clases(),
          enVivos: _Repositorio([_enVivo('a', DateTime(2026, 11, 9, 19))]),
          onReportarClase: (_) {},
          ahora: () => DateTime(2026, 11, 8, 19),
          abrirEnlace: (uri) async {
            abiertos.add(uri);
            return true;
          },
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Ana Quispe'), findsWidgets);
    expect(find.text('Historia del Perú'), findsOneWidget);
    expect(find.text('Repaso de los incas'), findsOneWidget);
    expect(find.text('1 d 00:00:00'), findsOneWidget);
    expect(find.text('Sus clases'), findsOneWidget);
    expect(find.text('Pachacútec'), findsOneWidget);

    await tester.tap(find.text('TikTok'));
    await tester.pump();
    expect(abiertos.single.host, 'www.tiktok.com');

    await tester.pumpWidget(const SizedBox());
  });
}
