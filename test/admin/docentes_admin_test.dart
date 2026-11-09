import 'package:academiapp_v2/admin/docentes/docentes_page.dart';
import 'package:academiapp_v2/admin/docentes/repositorio_docentes_admin.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/teachers/domain/solicitud_docente.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SolicitudDocente _solicitud(
  String uid,
  String nombre,
  EstadoSolicitudDocente estado,
) => SolicitudDocente(
  uid: uid,
  nombre: nombre,
  correo: '$uid@b.pe',
  celular: '987654321',
  cursos: 'Historia del Perú',
  enlaces: ['https://youtube.com/@$uid'],
  mensaje: 'Enseño historia hace cinco años en Huamanga.',
  estado: estado,
  creadaEn: DateTime(2026, 11, 7),
);

class _Repositorio implements RepositorioDocentesAdmin {
  final todas = [
    _solicitud('ana', 'Ana Quispe', EstadoSolicitudDocente.pendiente),
    _solicitud('luis', 'Luis Huamán', EstadoSolicitudDocente.aprobada),
  ];
  final acciones = <String>[];

  @override
  Stream<int> pendientes() => const Stream.empty();

  @override
  Future<List<SolicitudDocente>> solicitudes(
    EstadoSolicitudDocente estado,
  ) async => [
    for (final s in todas)
      if (s.estado == estado) s,
  ];

  @override
  Future<void> aprobar(SolicitudDocente s) async =>
      acciones.add('aprobar ${s.uid}');

  @override
  Future<void> rechazar(SolicitudDocente s, String motivo) async =>
      acciones.add('rechazar ${s.uid}: $motivo');

  @override
  Future<void> retirar(SolicitudDocente s, String motivo) async =>
      acciones.add('retirar ${s.uid}: $motivo');
}

void main() {
  late _Repositorio repositorio;
  final abiertos = <Uri>[];

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: DocentesPage(
            repositorio: repositorio,
            abrirEnlace: (uri) async {
              abiertos.add(uri);
              return true;
            },
            ahora: () => DateTime(2026, 11, 8),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repositorio = _Repositorio();
    abiertos.clear();
  });

  testWidgets('revisa el canal y aprueba con confirmación', (tester) async {
    await montar(tester);

    expect(find.text('Por revisar · 1'), findsOneWidget);
    expect(find.text('Ana Quispe'), findsWidgets);
    expect(find.text('Luis Huamán'), findsNothing);

    await tester.tap(find.text('https://youtube.com/@ana'));
    await tester.pump();
    expect(abiertos.single.host, 'youtube.com');

    await tester.tap(find.text('Escribir por WhatsApp'));
    await tester.pump();
    expect(abiertos.last.toString(), 'https://wa.me/51987654321');

    await tester.tap(find.widgetWithText(FilledButton, 'Aprobar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Aprobar').last);
    await tester.pumpAndSettle();
    expect(repositorio.acciones, ['aprobar ana']);
    expect(find.text('Docente aprobado.'), findsOneWidget);
  });

  testWidgets('no aprueba con un motivo sugerido', (tester) async {
    await montar(tester);

    await tester.tap(find.text('No aprobar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('El enlace no abre o es privado.'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'No aprobar'));
    await tester.pumpAndSettle();
    expect(repositorio.acciones, [
      'rechazar ana: El enlace no abre o es privado.',
    ]);
  });

  testWidgets('a un docente aprobado se le puede retirar la cuenta', (
    tester,
  ) async {
    await montar(tester);

    await tester.tap(find.text('Aprobados'));
    await tester.pumpAndSettle();
    expect(find.text('Luis Huamán'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Aprobar'), findsNothing);

    await tester.tap(find.text('Retirar cuenta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo (lo ve el docente)'),
      'Subió clases ajenas.',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
    await tester.pumpAndSettle();
    expect(repositorio.acciones, ['retirar luis: Subió clases ajenas.']);
  });
}
