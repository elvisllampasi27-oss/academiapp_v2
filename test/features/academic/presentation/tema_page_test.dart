import 'package:academiapp_v2/features/academic/domain/entities/contenido.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/services/obtener_material_tema_service.dart';
import 'package:academiapp_v2/features/academic/presentation/pages/tema_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes_material.dart';

void main() {
  const tema = Tema(
    id: 'geografia-01',
    cursoId: 'geografia',
    titulo: 'Geografía: principios',
    orden: 1,
  );
  const curso = Curso(
    id: 'geografia',
    areaId: 'ciencias_sociales',
    nombre: 'Geografía',
    orden: 15,
  );

  Widget pagina(
    RepositorioRecursoEnMemoria recursos, {
    List<Contenido> contenidos = const [],
    List<Uri>? abiertos,
  }) {
    return MaterialApp(
      home: TemaPage(
        tema: tema,
        curso: curso,
        versionId: 'version-1',
        service: ObtenerMaterialTemaService(
          repositorioContenido: RepositorioContenidoEnMemoria(contenidos),
          repositorioRecurso: recursos,
        ),
        abrirEnlace: (uri) async {
          abiertos?.add(uri);
          return true;
        },
      ),
    );
  }

  testWidgets('muestra contenidos y recursos y abre el enlace', (tester) async {
    final abiertos = <Uri>[];
    await tester.pumpWidget(
      pagina(
        RepositorioRecursoEnMemoria([
          recurso('r1', titulo: 'Clase grabada', ubicacion: 'AbCdEfGhIjK'),
        ]),
        contenidos: const [
          Contenido(
            id: 'c1',
            temaId: 'geografia-01',
            nombre: 'Espacio geográfico',
            orden: 1,
          ),
        ],
        abiertos: abiertos,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Geografía'), findsOneWidget);
    expect(find.text('Qué aprenderás'), findsOneWidget);
    expect(find.text('Espacio geográfico'), findsOneWidget);
    expect(find.text('Clase grabada'), findsOneWidget);

    await tester.tap(find.text('Clase grabada'));
    await tester.pumpAndSettle();

    expect(abiertos.single.host, 'www.youtube.com');
  });

  testWidgets('tema sin material avisa que se esta preparando', (tester) async {
    await tester.pumpWidget(pagina(RepositorioRecursoEnMemoria()));
    await tester.pumpAndSettle();

    expect(
      find.text('El material de este tema se está preparando.'),
      findsOneWidget,
    );
  });

  testWidgets('si falla la carga permite reintentar', (tester) async {
    final recursos = RepositorioRecursoEnMemoria([recurso('r1')])
      ..fallar = true;
    await tester.pumpWidget(pagina(recursos));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo cargar el material del tema.'),
      findsOneWidget,
    );

    recursos.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Recurso'), findsOneWidget);
  });

  testWidgets('un enlace invalido muestra aviso en lugar de fallar', (
    tester,
  ) async {
    await tester.pumpWidget(
      pagina(
        RepositorioRecursoEnMemoria([
          recurso('r1', titulo: 'PDF roto', ubicacion: 'http://inseguro.pe'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PDF roto'));
    await tester.pump();

    expect(find.text('No se pudo abrir este material.'), findsOneWidget);
  });
}
