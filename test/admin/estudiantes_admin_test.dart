import 'package:academiapp_v2/admin/estudiantes/estudiantes_page.dart';
import 'package:academiapp_v2/admin/estudiantes/ficha_estudiante_page.dart';
import 'package:academiapp_v2/admin/estudiantes/modelo_estudiantes.dart';
import 'package:academiapp_v2/admin/estudiantes/repositorio_estudiantes_admin.dart';
import 'package:academiapp_v2/admin/resumen/resumen_page.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curriculo.dart';
import 'package:academiapp_v2/features/academic/domain/entities/version_academica.dart';
import 'package:academiapp_v2/features/enrollment/domain/entities/matricula.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final hoy = DateTime(2026, 11, 1, 10);

final ana = EstudianteAdmin(
  uid: 'ana',
  nombre: 'Ana Quispe',
  correo: 'ana@mail.pe',
  carrera: 'Medicina Humana',
  ultimaActividad: DateTime(2026, 11, 1, 9),
  matricula: Matricula(
    id: 'm1',
    usuarioId: 'ana',
    versionId: 'v1',
    fechaMatricula: DateTime(2026, 10, 25),
    fechaInicioAcademico: DateTime(2026, 10, 26),
    estado: EstadoMatricula.activa,
  ),
);

const beto = EstudianteAdmin(
  uid: 'beto',
  nombre: 'Beto Ramos',
  correo: 'beto@mail.pe',
);

class RepositorioFalso implements RepositorioEstudiantesAdmin {
  final cambios = <String>[];

  @override
  Future<List<EstudianteAdmin>> estudiantes() async => [ana, beto];

  @override
  Future<List<VersionAcademica>> versiones() async => [
    VersionAcademica(
      id: 'v1',
      codigo: '2026-II',
      nombre: 'Ciclo 2026-II',
      fechaApertura: DateTime(2026, 10, 1),
      estado: EstadoVersionAcademica.activa,
    ),
  ];

  @override
  Future<Curriculo> curriculo(String versionId) async =>
      const Curriculo(versionId: 'v1', areas: [], cursos: [], temas: []);

  @override
  Future<List<AccionAdmin>> accionesRecientes({int limite = 8}) async => [
    AccionAdmin(
      tipo: 'matricula',
      descripcion: 'Matriculó a Ana Quispe en Ciclo 2026-II',
      usuarioId: 'ana',
      adminCorreo: 'admin@mail.pe',
      fecha: DateTime(2026, 10, 25),
    ),
  ];

  @override
  Future<List<ActividadDia>> actividadReciente({int dias = 14}) async => [
    for (var i = 0; i < dias; i++)
      ActividadDia(DateTime(2026, 10, 19 + i), i % 4, i % 3 == 0 ? 1 : 0),
  ];

  @override
  Future<FichaEstudiante> ficha(String uid) async => FichaEstudiante(
    estudiante: ana,
    matriculas: [ana.matricula!],
    version: (await versiones()).first,
    fin: null,
    clasesCompletas: 12,
    totalTemas: 205,
    respuestas: 20,
    correctas: 15,
    simulacros: const [],
    dominio: const [DominioCurso('Álgebra', 0.8)],
    reforzar: const [],
    acciones: const [],
  );

  @override
  Future<void> matricular({
    required EstudianteAdmin estudiante,
    required VersionAcademica version,
    required DateTime fechaMatricula,
    required DateTime inicio,
  }) async => cambios.add('matricular ${estudiante.uid}');

  @override
  Future<void> cambiarInicio({
    required EstudianteAdmin estudiante,
    required Matricula matricula,
    required DateTime inicio,
  }) async => cambios.add('inicio');

  @override
  Future<void> cambiarEstado({
    required EstudianteAdmin estudiante,
    required Matricula matricula,
    required EstadoMatricula estado,
  }) async => cambios.add('estado ${estado.name}');
}

Widget envolver(Widget pagina) => MaterialApp(
  theme: temaPanel(),
  home: Scaffold(body: pagina),
);

void main() {
  testWidgets('estudiantes: lista, filtra y abre la ficha', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    String? abierto;
    await tester.pumpWidget(
      envolver(
        EstudiantesPage(
          repositorio: RepositorioFalso(),
          onAbrir: (uid) => abierto = uid,
          ahora: () => hoy,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Quispe'), findsOneWidget);
    expect(find.text('Beto Ramos'), findsOneWidget);
    expect(find.text('26 oct · día 6'), findsOneWidget);

    await tester.tap(find.text('Registrados sin matrícula'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Quispe'), findsNothing);
    expect(find.text('Beto Ramos'), findsOneWidget);

    await tester.tap(find.text('Beto Ramos'));
    expect(abierto, 'beto');
  });

  testWidgets('ficha: muestra el avance y suspende con confirmación', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repositorio = RepositorioFalso();
    await tester.pumpWidget(
      envolver(
        FichaEstudiantePage(
          uid: 'ana',
          repositorio: repositorio,
          onVolver: () {},
          ahora: () => hoy,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('75 %'), findsOneWidget); // 15 de 20 en prácticas
    expect(find.text('Álgebra'), findsOneWidget);
    expect(find.text('Ciclo 2026-II'), findsOneWidget);

    await tester.tap(find.text('Suspender matrícula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspender'));
    await tester.pumpAndSettle();

    expect(repositorio.cambios, ['estado suspendida']);
  });

  testWidgets('resumen: cifras y lo que requiere atención', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    FiltroEstudiantes? pedido;
    await tester.pumpWidget(
      envolver(
        ResumenPage(
          repositorio: RepositorioFalso(),
          onAbrirEstudiante: (_) {},
          onVerEstudiantes: (f) => pedido = f,
          correoAdmin: 'elvis.llampasi.27@unsch.edu.pe',
          ahora: () => hoy,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buenos días, Elvis'), findsOneWidget);
    expect(find.text('Matriculados activos'), findsOneWidget);
    expect(find.text('Actividad de los últimos 14 días'), findsOneWidget);
    expect(find.text('1 con cuenta y sin matrícula'), findsOneWidget);
    expect(
      find.text('Matriculó a Ana Quispe en Ciclo 2026-II'),
      findsOneWidget,
    );

    await tester.tap(find.text('1 con cuenta y sin matrícula'));
    expect(pedido, FiltroEstudiantes.sinMatricula);
  });
}
