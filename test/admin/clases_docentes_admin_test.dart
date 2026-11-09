import 'package:academiapp_v2/admin/docentes/clases_docentes_page.dart';
import 'package:academiapp_v2/admin/docentes/repositorio_clases_docentes_admin.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/teachers/domain/clase_docente.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ClaseDocente _clase(String id, String titulo, EstadoClaseDocente estado) =>
    ClaseDocente(
      id: id,
      docenteUid: 'profe',
      docenteNombre: 'Ana Quispe',
      temaId: 'his-03',
      temaTitulo: 'Los incas',
      cursoNombre: 'Historia del Perú',
      titulo: titulo,
      videoId: 'pRRaLT4H-9s',
      estado: estado,
      corazones: 5,
      creadaEn: DateTime(2026, 11, 7),
    );

class _Repositorio implements RepositorioClasesDocentesAdmin {
  final todas = [
    _clase('a', 'El Tahuantinsuyo', EstadoClaseDocente.pendiente),
    _clase('b', 'Pachacútec', EstadoClaseDocente.aprobada),
  ];
  final acciones = <String>[];

  @override
  Stream<int> pendientes() => const Stream.empty();

  @override
  Future<List<ClaseDocente>> clases(EstadoClaseDocente estado) async => [
    for (final c in todas)
      if (c.estado == estado) c,
  ];

  @override
  Future<void> publicar(ClaseDocente c) async =>
      acciones.add('publicar ${c.id}');

  @override
  Future<void> rechazar(ClaseDocente c, String motivo) async =>
      acciones.add('rechazar ${c.id}: $motivo');
}

void main() {
  late _Repositorio repositorio;
  final abiertos = <Uri>[];

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: ClasesDocentesPage(
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

  testWidgets('mira el video y la publica', (tester) async {
    await montar(tester);

    expect(find.text('Por revisar · 1'), findsOneWidget);
    await tester.tap(find.text('Ver en YouTube'));
    await tester.pump();
    expect(abiertos.single.queryParameters['v'], 'pRRaLT4H-9s');

    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(repositorio.acciones, ['publicar a']);
    expect(find.text('Clase publicada.'), findsOneWidget);
  });

  testWidgets('no la publica con un motivo', (tester) async {
    await montar(tester);

    await tester.tap(find.text('No publicar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('El video no corresponde al tema.'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'No publicar'));
    await tester.pumpAndSettle();
    expect(repositorio.acciones, [
      'rechazar a: El video no corresponde al tema.',
    ]);
  });

  testWidgets('una publicada se puede ocultar', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Publicadas'));
    await tester.pumpAndSettle();
    expect(find.text('Pachacútec'), findsWidgets);
    expect(find.text('Publicar'), findsNothing);

    await tester.tap(find.text('Ocultar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo (lo ve el docente)'),
      'Lo reportaron varios alumnos.',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ocultar'));
    await tester.pumpAndSettle();
    expect(repositorio.acciones, ['rechazar b: Lo reportaron varios alumnos.']);
  });
}
