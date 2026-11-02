import 'dart:convert';
import 'dart:typed_data';

import 'package:academiapp_v2/admin/importar/dialogo_importar_json.dart';
import 'package:academiapp_v2/admin/importar/importar_json.dart';
import 'package:academiapp_v2/admin/importar/subir_imagenes.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String url(String archivo) => 'https://x.web.app/temas/v1/t/$archivo';

void main() {
  test('lee el formato de la V1: clave por texto, latex e imágenes', () {
    final r = leerPreguntasJson(
      jsonEncode({
        'secciones': [
          {'nombre': 'Matemática', 'desde': 1, 'hasta': 1},
        ],
        'preguntas': [
          {
            'enunciado': r'Si $x^2 = 4$, halla $x>0$',
            'opciones': ['1', '2', '3'],
            'clave': '2',
            'solucion': r'$x = 2$',
            'imagen': 'fig 1.png',
          },
          {
            'latex': 'Pregunta solo en latex',
            'opciones': ['a', 'b'],
            'correcta': 'b',
            'imagen': 'https://otro.pe/f.png',
            'seccion': 'Ciencias',
          },
          {
            'enunciado': 'Sin correcta',
            'opciones': ['a', 'b'],
          },
          {
            'enunciado': 'Una sola opción',
            'opciones': ['a'],
            'correcta': 0,
          },
        ],
      }),
      urlDeArchivo: url,
    );

    expect(r.preguntas.length, 2);
    expect(r.avisos.map((a) => a.numero), [3, 4]);
    final [primera, segunda] = r.preguntas;
    expect(primera.correcta, 1);
    expect(primera.tieneLatex, isTrue);
    expect(primera.imagen, 'https://x.web.app/temas/v1/t/fig 1.png');
    expect(primera.archivosEn(url('')), ['fig 1.png']);
    expect(segunda.enunciado, 'Pregunta solo en latex');
    expect(segunda.correcta, 1);
    expect(segunda.archivosEn(url('')), isEmpty);
    expect(r.seccionDe(primera), 'Matemática');
    expect(r.seccionDe(segunda), 'Ciencias');
    expect((r.conLatex, r.conImagen), (1, 2));
  });

  test('acepta una lista sola y el formato de tool/ (evaluaciones)', () {
    final pregunta = {
      'enunciado': '¿2+2?',
      'opciones': ['3', '4'],
      'correcta': 1,
    };
    expect(
      leerPreguntasJson(
        jsonEncode([pregunta]),
        urlDeArchivo: url,
      ).preguntas.single.correcta,
      1,
    );
    expect(
      leerPreguntasJson(
        jsonEncode({
          'evaluaciones': [
            {
              'temaId': 't',
              'preguntas': [pregunta],
            },
          ],
        }),
        urlDeArchivo: url,
      ).preguntas.length,
      1,
    );
    expect(
      () => leerPreguntasJson('{no es json', urlDeArchivo: url),
      throwsFormatException,
    );
    expect(
      () => leerPreguntasJson('{"otra": 1}', urlDeArchivo: url),
      throwsFormatException,
    );
  });

  test('fechas y títulos de los exámenes', () {
    expect(fechaIsoDeCarpeta('16-11-2025'), '2025-11-16');
    expect(fechaIsoDeCarpeta('2025-11-16'), isNull);
    expect(
      tituloExamen('exonerados', '2025-11-16'),
      'Exonerados · 16 nov 2025',
    );
  });

  testWidgets('el diálogo revisa el JSON y devuelve lo elegido', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    ImportacionElegida? elegida;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  elegida = await mostrarImportarJson(
                    context,
                    titulo: 'Importar',
                    urlDeArchivo: url,
                    carpetaImagenes: 'hosting/temas/v1/t/',
                    abrirArchivo: () async => jsonEncode([
                      {
                        'enunciado': r'$1+1$',
                        'opciones': ['1', '2'],
                        'correcta': 1,
                      },
                    ]),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir archivo .json'));
    await tester.pumpAndSettle();

    expect(find.text('1 listas'), findsOneWidget);
    expect(find.text('1 con LaTeX'), findsOneWidget);

    await tester.tap(find.text('Importar 1 preguntas'));
    await tester.pumpAndSettle();
    expect(elegida?.resultado.preguntas.single.correcta, 1);
    expect(elegida?.reemplazar, isFalse);
  });

  testWidgets('sube las imágenes elegidas del computador por su nombre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final subidas = <String>[];
    ImportacionElegida? elegida;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  elegida = await mostrarImportarJson(
                    context,
                    titulo: 'Importar',
                    urlDeArchivo: url,
                    carpetaImagenes: 'temas/v1/t',
                    imagenes: _ServicioFalso(subidas),
                    elegirImagenes: () async => [
                      ArchivoImagen('FIG.png', Uint8List(3)),
                      ArchivoImagen('otra.png', Uint8List(3)),
                    ],
                    abrirArchivo: () async => jsonEncode([
                      {
                        'enunciado': 'Mira la figura',
                        'opciones': ['1', '2'],
                        'correcta': 0,
                        'imagen': 'fig.png',
                      },
                    ]),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir archivo .json'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subir imágenes'));
    await tester.pumpAndSettle();

    expect(subidas, ['temas/v1/t/fig.png']);
    expect(find.text('Las 1 imágenes están subidas.'), findsOneWidget);
    await tester.tap(find.text('Importar 1 preguntas'));
    await tester.pumpAndSettle();
    expect(
      elegida?.resultado.preguntas.single.imagen,
      'http://localhost:9199/temas/v1/t/fig.png',
    );
  });
}

class _ServicioFalso implements ServicioImagenesAdmin {
  final List<String> rutas;
  _ServicioFalso(this.rutas);

  @override
  Future<String> subir({required String ruta, required Uint8List bytes}) async {
    rutas.add(ruta);
    return 'http://localhost:9199/$ruta';
  }
}
