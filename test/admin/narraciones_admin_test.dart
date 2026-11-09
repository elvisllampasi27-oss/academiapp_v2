import 'dart:typed_data';

import 'package:academiapp_v2/admin/contenido/narraciones_admin.dart';
import 'package:academiapp_v2/admin/contenido/seccion_narraciones_admin.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/narrations/domain/narracion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repositorio implements RepositorioNarracionesAdmin {
  final lista = <Narracion>[
    const Narracion(
      id: 'n1',
      versionId: 'v1',
      temaId: 'lit-03',
      titulo: 'Paco Yunque',
      tipo: 'Cuento',
      url: 'https://x.pe/n1.mp3',
      rutaAudio: 'narraciones/v1/lit-03/n1.mp3',
    ),
  ];
  final agregadas = <Map<String, Object?>>[];
  final eliminadas = <String>[];

  @override
  Future<List<Narracion>> delTema({
    required String versionId,
    required String temaId,
  }) async => List.of(lista);

  @override
  Future<void> agregar({
    required String versionId,
    required String temaId,
    required String tituloTema,
    required String titulo,
    required String tipo,
    String? descripcion,
    ArchivoAudio? audio,
    String? enlace,
  }) async {
    agregadas.add({
      'titulo': titulo,
      'tipo': tipo,
      'descripcion': descripcion,
      'audio': audio?.nombre,
      'enlace': enlace,
    });
    lista.add(
      Narracion(
        id: 'n${lista.length + 1}',
        versionId: versionId,
        temaId: temaId,
        titulo: titulo,
        tipo: tipo,
        url: enlace ?? 'https://storage/x.mp3',
      ),
    );
  }

  @override
  Future<void> eliminar(Narracion narracion) async {
    eliminadas.add(narracion.id);
    lista.removeWhere((n) => n.id == narracion.id);
  }
}

void main() {
  late _Repositorio repositorio;
  ArchivoAudio? elegido;

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeccionNarracionesAdmin(
              versionId: 'v1',
              temaId: 'lit-03',
              tituloTema: 'Vanguardismo',
              repositorio: repositorio,
              elegirAudio: () async => elegido,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repositorio = _Repositorio();
    elegido = null;
  });

  testWidgets('lista las del tema y pide lo que falta', (tester) async {
    await montar(tester);

    expect(find.text('Paco Yunque'), findsOneWidget);
    expect(find.text('Audio subido'), findsOneWidget);

    await tester.tap(find.text('Agregar narración').last);
    await tester.pump();
    expect(find.text('Escribe el título de la narración.'), findsOneWidget);
    expect(repositorio.agregadas, isEmpty);
  });

  testWidgets('con "Otro" se escribe el tipo; un enlace sirve para probar', (
    tester,
  ) async {
    await montar(tester);
    expect(find.text('Escribe el tipo'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tipoOtro).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Crónica de Ayacucho',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Escribe el tipo'),
      ' Crónica ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'O pega un enlace (solo para probar)'),
      'https://x.pe/cronica.mp3',
    );
    await tester.tap(find.text('Agregar narración').last);
    await tester.pumpAndSettle();

    expect(repositorio.agregadas.single, {
      'titulo': 'Crónica de Ayacucho',
      'tipo': 'Crónica',
      'descripcion': '',
      'audio': null,
      'enlace': 'https://x.pe/cronica.mp3',
    });
    expect(find.text('Crónica de Ayacucho'), findsOneWidget);
    // El formulario queda limpio y vuelve al primer tipo.
    expect(find.text('Escribe el tipo'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(DropdownButtonFormField<String>),
        matching: find.text(tiposNarracion.first),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sube el audio elegido y elimina con confirmación', (
    tester,
  ) async {
    elegido = ArchivoAudio('cuento.mp3', Uint8List(3 * 1024 * 1024));
    await montar(tester);

    await tester.tap(find.text('Elegir audio'));
    await tester.pumpAndSettle();
    expect(find.text('cuento.mp3 · 3.0 MB'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'O pega un enlace (solo para probar)'),
      findsNothing,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'El caballero Carmelo',
    );
    await tester.tap(find.text('Agregar narración').last);
    await tester.pumpAndSettle();
    expect(repositorio.agregadas.single['audio'], 'cuento.mp3');
    expect(repositorio.agregadas.single['enlace'], isNull);
    expect(repositorio.agregadas.single['tipo'], tiposNarracion.first);

    await tester.tap(find.byTooltip('Eliminar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(repositorio.eliminadas, ['n1']);
    expect(find.text('Paco Yunque'), findsNothing);
  });
}
