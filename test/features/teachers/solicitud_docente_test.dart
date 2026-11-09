import 'package:academiapp_v2/features/teachers/domain/solicitud_docente.dart';
import 'package:academiapp_v2/features/teachers/infrastructure/repositorio_docentes_firestore.dart';
import 'package:academiapp_v2/features/teachers/presentation/solicitud_docente_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mensaje = 'Enseño historia hace cinco años en Huamanga.';

class _Repositorio implements RepositorioDocentes {
  SolicitudDocente? actual;
  final enviadas = <Map<String, Object?>>[];

  _Repositorio(this.actual);

  @override
  Future<SolicitudDocente?> miSolicitud(String uid) async => actual;

  @override
  Future<PerfilDocente?> perfil(String uid) async => null;

  @override
  Future<void> solicitar({
    required String uid,
    required String nombre,
    required String correo,
    required String celular,
    required String cursos,
    required List<String> enlaces,
    required String mensaje,
  }) async {
    enviadas.add({
      'celular': celular,
      'cursos': cursos,
      'enlaces': enlaces,
      'mensaje': mensaje,
    });
    actual = SolicitudDocente(
      uid: uid,
      nombre: nombre,
      correo: correo,
      celular: celular,
      cursos: cursos,
      enlaces: enlaces,
      mensaje: mensaje,
      estado: EstadoSolicitudDocente.pendiente,
      creadaEn: DateTime(2026, 11, 8),
    );
  }
}

void main() {
  group('solicitud', () {
    test('qué falta para enviarla', () {
      String? error({
        String celular = '987 654 321',
        String cursos = 'Historia',
        List<String> enlaces = const ['https://youtube.com/@ana'],
        String mensaje = _mensaje,
      }) => errorSolicitudDocente(
        celular: celular,
        cursos: cursos,
        enlaces: enlaces,
        mensaje: mensaje,
      );

      expect(error(), isNull);
      expect(error(celular: '+51 987-654-321'), isNull);
      expect(error(celular: '12345678'), contains('celular'));
      expect(celularLimpio('+51 987 654 321'), '987654321');
      expect(error(cursos: ' a '), contains('curso'));
      expect(error(enlaces: const []), contains('YouTube'));
      expect(error(enlaces: const ['youtube.com/@ana']), contains('https://'));
      expect(error(enlaces: const ['http://x.pe']), contains('https://'));
      expect(error(mensaje: 'Soy profe'), contains('más de ti'));
      expect(
        enlacesLimpios([' https://a.pe ', '', 'https://a.pe', 'https://b.pe']),
        ['https://a.pe', 'https://b.pe'],
      );
    });

    test('se lee de Firestore; un estado desconocido no sirve', () {
      final s = solicitudDesdeMapa('u1', {
        'nombre': 'Ana',
        'correo': 'a@b.pe',
        'cursos': 'Historia',
        'enlaces': ['https://youtube.com/@ana', 3],
        'mensaje': _mensaje,
        'estado': 'rechazada',
        'motivo': 'El enlace no abre.',
        'creadaEn': Timestamp.fromDate(DateTime(2026, 11, 1)),
      })!;
      expect(s.estado, EstadoSolicitudDocente.rechazada);
      expect(s.enlaces, ['https://youtube.com/@ana']);
      expect(s.motivo, 'El enlace no abre.');
      expect(s.creadaEn, DateTime(2026, 11, 1));
      expect(solicitudDesdeMapa('u1', {'estado': 'otro'}), isNull);
    });
  });

  Future<void> montar(WidgetTester tester, _Repositorio repositorio) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SolicitudDocentePage(
          uid: 'u1',
          nombre: 'Ana',
          correo: 'a@b.pe',
          repositorio: repositorio,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pide la cuenta y luego ve que está en revisión', (tester) async {
    final repositorio = _Repositorio(null);
    await montar(tester, repositorio);

    expect(find.text('¿Eres docente?'), findsOneWidget);
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pump();
    expect(
      find.text('Escribe tu celular (9 dígitos, empieza con 9).'),
      findsOneWidget,
    );
    expect(repositorio.enviadas, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextField, 'Tu celular (WhatsApp)'),
      '987 654 321',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Curso o cursos que enseñas'),
      'Historia del Perú',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Tu canal de YouTube o red social'),
      'https://youtube.com/@ana',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Cuéntanos de ti'),
      _mensaje,
    );
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(repositorio.enviadas.single, {
      'celular': '987 654 321',
      'cursos': 'Historia del Perú',
      'enlaces': ['https://youtube.com/@ana'],
      'mensaje': _mensaje,
    });
    expect(find.text('Tu solicitud está en revisión'), findsOneWidget);
  });

  testWidgets('si no se aprobó ve el motivo y la corrige', (tester) async {
    final repositorio = _Repositorio(
      SolicitudDocente(
        uid: 'u1',
        nombre: 'Ana',
        correo: 'a@b.pe',
        celular: '987654321',
        cursos: 'Historia',
        enlaces: const ['https://youtube.com/@ana'],
        mensaje: _mensaje,
        estado: EstadoSolicitudDocente.rechazada,
        creadaEn: DateTime(2026, 11, 1),
        motivo: 'El enlace no abre.',
      ),
    );
    await montar(tester, repositorio);

    expect(find.text('Tu solicitud no fue aprobada'), findsOneWidget);
    expect(find.text('El enlace no abre.'), findsOneWidget);

    await tester.tap(find.text('Corregir y volver a enviar'));
    await tester.pumpAndSettle();
    expect(find.text('Motivo anterior: El enlace no abre.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Otro enlace (opcional)').first,
      'https://tiktok.com/@ana',
    );
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(repositorio.enviadas.single['enlaces'], [
      'https://youtube.com/@ana',
      'https://tiktok.com/@ana',
    ]);
    expect(find.text('Tu solicitud está en revisión'), findsOneWidget);
  });
}
