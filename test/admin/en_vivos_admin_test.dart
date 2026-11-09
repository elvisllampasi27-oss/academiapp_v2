import 'package:academiapp_v2/admin/docentes/en_vivos_admin_page.dart';
import 'package:academiapp_v2/admin/docentes/repositorio_en_vivos_admin.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/teachers/domain/en_vivo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _ahora = DateTime(2026, 11, 8, 19, 30);

EnVivo _enVivo(
  String id,
  String titulo,
  EstadoEnVivo estado,
  DateTime inicio,
) => EnVivo(
  id: id,
  docenteUid: 'profe',
  docenteNombre: 'Ana Quispe',
  titulo: titulo,
  plataforma: PlataformaEnVivo.meet,
  enlace: 'https://meet.google.com/abc-defg-hij',
  inicio: inicio,
  fin: inicio.add(const Duration(hours: 1)),
  estado: estado,
);

class _Repositorio implements RepositorioEnVivosAdmin {
  final todos = [
    _enVivo(
      'a',
      'Repaso de los incas',
      EstadoEnVivo.pendiente,
      DateTime(2026, 11, 9, 19),
    ),
    _enVivo(
      'b',
      'Dudas de álgebra',
      EstadoEnVivo.aprobado,
      DateTime(2026, 11, 8, 19),
    ),
  ];
  final acciones = <String>[];

  @override
  Stream<int> pendientes() => const Stream.empty();

  @override
  Future<List<EnVivo>> enVivos(EstadoEnVivo estado) async => [
    for (final e in todos)
      if (e.estado == estado) e,
  ];

  @override
  Future<void> aprobar(EnVivo e) async => acciones.add('aprobar ${e.id}');

  @override
  Future<void> rechazar(EnVivo e, String motivo) async =>
      acciones.add('rechazar ${e.id}: $motivo');

  @override
  Future<void> terminar(EnVivo e) async => acciones.add('terminar ${e.id}');
}

void main() {
  late _Repositorio repositorio;

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: EnVivosAdminPage(
            repositorio: repositorio,
            abrirEnlace: (_) async => true,
            ahora: () => _ahora,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => repositorio = _Repositorio());

  testWidgets('aprueba uno por revisar', (tester) async {
    await montar(tester);

    expect(find.text('Por revisar · 1'), findsOneWidget);
    expect(find.text('Repaso de los incas'), findsWidgets);
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    expect(repositorio.acciones, ['aprobar a']);
  });

  testWidgets('no aprueba con un motivo sugerido', (tester) async {
    await montar(tester);

    await tester.tap(find.text('No aprobar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elige otro horario, por favor.'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'No aprobar'));
    await tester.pumpAndSettle();
    expect(repositorio.acciones, [
      'rechazar a: Elige otro horario, por favor.',
    ]);
  });

  testWidgets('termina uno que está en vivo', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Aprobados'));
    await tester.pumpAndSettle();
    expect(find.text('En vivo ahora'), findsOneWidget);

    await tester.tap(find.text('Terminar ahora'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Terminar'));
    await tester.pumpAndSettle();
    expect(repositorio.acciones, ['terminar b']);
  });
}
