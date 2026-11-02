import 'package:academiapp_v2/admin/avisos/avisos_page.dart';
import 'package:academiapp_v2/admin/avisos/repositorio_avisos_admin.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/academic/domain/entities/version_academica.dart';
import 'package:academiapp_v2/features/avisos/domain/aviso.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final hoy = DateTime(2026, 11, 2, 10);

final version = VersionAcademica(
  id: 'v1',
  codigo: 'v1',
  nombre: 'Ciclo 2026-II',
  fechaApertura: DateTime(2026, 10, 26),
  estado: EstadoVersionAcademica.activa,
);

class Falso implements RepositorioAvisosAdmin {
  final lista = <Aviso>[
    Aviso(
      id: 'a1',
      titulo: 'Simulacro el sábado',
      mensaje: 'A las 9:00.',
      hasta: DateTime(2026, 11, 7, 23, 59),
      creadoEn: DateTime(2026, 11, 1),
    ),
  ];
  final hechos = <String>[];

  @override
  Future<List<Aviso>> avisos() async => List.of(lista);

  @override
  Future<void> guardar(Aviso aviso, {required bool nuevo}) async {
    hechos.add('${nuevo ? 'nuevo' : 'editar'} ${aviso.titulo} ${aviso.activo}');
    if (nuevo) lista.add(aviso);
  }

  @override
  Future<void> eliminar(Aviso aviso) async {
    hechos.add('eliminar ${aviso.id}');
    lista.removeWhere((a) => a.id == aviso.id);
  }
}

Future<Falso> abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final falso = Falso();
  await tester.pumpWidget(
    MaterialApp(
      theme: temaPanel(),
      home: Scaffold(
        body: AvisosPage(
          repositorio: falso,
          versiones: () async => [version],
          ahora: () => hoy,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return falso;
}

void main() {
  testWidgets('avisos: publica uno nuevo para todos', (tester) async {
    final falso = await abrir(tester);
    expect(find.text('Simulacro el sábado'), findsOneWidget);
    expect(find.text('Se ve en la app'), findsOneWidget);

    await tester.tap(find.text('Nuevo aviso'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'El lunes no hay clase',
    );
    await tester.pump();
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();

    expect(falso.hechos, ['nuevo El lunes no hay clase true']);
    expect(find.text('El lunes no hay clase'), findsOneWidget);
  });

  testWidgets('avisos: pausar y eliminar (con confirmación)', (tester) async {
    final falso = await abrir(tester);

    await tester.tap(find.text('Pausar'));
    await tester.pumpAndSettle();
    expect(falso.hechos, ['editar Simulacro el sábado false']);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar aviso'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Eliminar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(falso.hechos.last, 'eliminar a1');
    expect(find.text('Todavía no hay avisos.'), findsOneWidget);
  });
}
