import 'package:academiapp_v2/features/academic/domain/entities/contenido.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/progreso_clase.dart';
import 'package:academiapp_v2/features/academic/domain/entities/recurso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/services/obtener_material_tema_service.dart';
import 'package:academiapp_v2/features/academic/presentation/pages/tema_page.dart';
import 'package:academiapp_v2/features/academic/presentation/widgets/reproductor_clase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes_material.dart';

/// Reproductor de mentira: permite simular que el estudiante ve la clase.
class ReproductorFalso {
  AlAvanzarClase? alAvanzar;
  double? inicio;
  int pausas = 0;
  final idas = <double>[];

  Widget construir({
    required String videoId,
    required double inicio,
    required ControlClase control,
    required AlAvanzarClase alAvanzar,
  }) {
    this.alAvanzar = alAvanzar;
    this.inicio = inicio;
    control.vincular(pausar: () => pausas++, irA: idas.add);
    return Text('video $videoId');
  }

  void ver(double desde, double hasta, {double duracion = 100}) {
    for (var t = desde; t <= hasta; t += 0.5) {
      alAvanzar!(t, duracion);
    }
  }
}

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
  const contenido = Contenido(
    id: 'c1',
    temaId: 'geografia-01',
    nombre: 'Espacio geográfico',
    orden: 1,
  );

  late ReproductorFalso reproductor;
  late RepositorioProgresoClaseEnMemoria progreso;
  late List<Uri> abiertos;

  setUp(() {
    reproductor = ReproductorFalso();
    progreso = RepositorioProgresoClaseEnMemoria();
    abiertos = [];
  });

  Widget pagina(
    RepositorioRecursoEnMemoria recursos, {
    List<Contenido> contenidos = const [],
    bool conDudas = false,
  }) {
    return MaterialApp(
      home: TemaPage(
        tema: tema,
        curso: curso,
        versionId: 'version-1',
        usuarioId: 'u1',
        service: ObtenerMaterialTemaService(
          repositorioContenido: RepositorioContenidoEnMemoria(contenidos),
          repositorioRecurso: recursos,
        ),
        repositorioProgreso: progreso,
        reproductor: reproductor.construir,
        abrirEnlace: (uri) async {
          abiertos.add(uri);
          return true;
        },
        practica: (habilitada) =>
            Text(habilitada ? 'quiz activo' : 'quiz bloqueado'),
        dudas: conDudas
            ? (cerrar) => TextButton(
                onPressed: cerrar,
                child: const Text('panel de dudas'),
              )
            : null,
      ),
    );
  }

  final clase = recurso(
    'r1',
    titulo: 'Clase grabada',
    ubicacion: 'AbCdEfGhIjK',
  );
  final separata = recurso(
    'r2',
    tipo: TipoRecurso.pdf,
    titulo: 'Separata',
    ubicacion: 'https://ejemplo.pe/separata.pdf',
  );

  testWidgets('la clase se ve dentro de la app y activa el quiz al terminar', (
    tester,
  ) async {
    await tester.pumpWidget(
      pagina(
        RepositorioRecursoEnMemoria([clase]),
        contenidos: const [contenido],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('video AbCdEfGhIjK'), findsOneWidget);
    expect(find.text('Espacio geográfico'), findsOneWidget);
    expect(find.text('quiz bloqueado'), findsOneWidget);
    expect(
      find.text('Clase vista: 0 % · termínala para activar el quiz'),
      findsOneWidget,
    );

    reproductor.ver(0, 50);
    await tester.pump();
    expect(
      find.text('Clase vista: 50 % · termínala para activar el quiz'),
      findsOneWidget,
    );
    expect(progreso.guardados.values.single.tramos.single.$2, 50);

    reproductor.ver(50, 90);
    await tester.pump();

    expect(find.text('quiz activo'), findsOneWidget);
    expect(
      find.text('Clase vista por completo · quiz activado'),
      findsOneWidget,
    );
    expect(progreso.guardados.values.single.completada, isTrue);
  });

  testWidgets('si se salta una parte ofrece volver ahi', (tester) async {
    await tester.pumpWidget(pagina(RepositorioRecursoEnMemoria([clase])));
    await tester.pumpAndSettle();

    reproductor.ver(0, 10);
    reproductor.ver(80, 85);
    await tester.pump();

    expect(find.text('Te saltaste una parte desde 0:10'), findsOneWidget);
    expect(find.text('quiz bloqueado'), findsOneWidget);

    await tester.tap(find.text('Volver ahí'));
    expect(reproductor.idas, [10]);
  });

  testWidgets('continua donde se quedo y respeta la clase ya vista', (
    tester,
  ) async {
    await progreso.guardar(
      usuarioId: 'u1',
      progreso: const ProgresoClase(
        temaId: 'geografia-01',
        versionId: 'version-1',
        tramos: [(0, 100)],
        duracion: 100,
        completada: true,
      ),
    );

    await tester.pumpWidget(pagina(RepositorioRecursoEnMemoria([clase])));
    await tester.pumpAndSettle();

    expect(find.text('quiz activo'), findsOneWidget);
    // Ya vista: vuelve a empezar desde el inicio si la repasa.
    expect(reproductor.inicio, 0);
  });

  testWidgets('sin video el quiz esta activo y el material se abre fuera', (
    tester,
  ) async {
    await tester.pumpWidget(
      pagina(
        RepositorioRecursoEnMemoria([
          recurso(
            'r3',
            tipo: TipoRecurso.ejercicio,
            titulo: 'Ejercicios',
            ubicacion: 'https://ejemplo.pe/ejercicios.pdf',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('quiz activo'), findsOneWidget);
    expect(find.text('Más material'), findsOneWidget);

    await tester.tap(find.text('Ejercicios').first);
    await tester.pumpAndSettle();

    expect(abiertos.single.path, '/ejercicios.pdf');
  });

  testWidgets('el boton + abre la separata y las dudas pausando la clase', (
    tester,
  ) async {
    await tester.pumpWidget(
      pagina(RepositorioRecursoEnMemoria([clase, separata]), conDudas: true),
    );
    await tester.pumpAndSettle();

    // La separata va en el menú, no en la lista.
    expect(find.text('Más material'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Separata'));
    await tester.pumpAndSettle();

    expect(abiertos.single.path, '/separata.pdf');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolver dudas'));
    await tester.pumpAndSettle();

    expect(find.text('panel de dudas'), findsOneWidget);
    expect(reproductor.pausas, 1);

    await tester.tap(find.text('panel de dudas'));
    await tester.pumpAndSettle();

    expect(find.text('panel de dudas'), findsNothing);
  });

  testWidgets('tema sin material avisa que se esta preparando', (tester) async {
    await tester.pumpWidget(pagina(RepositorioRecursoEnMemoria()));
    await tester.pumpAndSettle();

    expect(
      find.text('El material de este tema se está preparando.'),
      findsOneWidget,
    );
    // Sin separata ni dudas no aparece el botón +.
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('si falla la carga permite reintentar', (tester) async {
    final recursos = RepositorioRecursoEnMemoria([clase])..fallar = true;
    await tester.pumpWidget(pagina(recursos));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo cargar el material del tema.'),
      findsOneWidget,
    );

    recursos.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('video AbCdEfGhIjK'), findsOneWidget);
  });

  testWidgets('un enlace invalido muestra aviso en lugar de fallar', (
    tester,
  ) async {
    await tester.pumpWidget(
      pagina(
        RepositorioRecursoEnMemoria([
          recurso(
            'r1',
            tipo: TipoRecurso.ejemplo,
            titulo: 'Ejemplo roto',
            ubicacion: 'http://inseguro.pe',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ejemplo roto'));
    await tester.pump();

    expect(find.text('No se pudo abrir este material.'), findsOneWidget);
  });
}
