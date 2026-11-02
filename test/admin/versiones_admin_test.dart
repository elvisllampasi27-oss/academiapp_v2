import 'package:academiapp_v2/admin/estudiantes/modelo_estudiantes.dart';
import 'package:academiapp_v2/admin/estudiantes/repositorio_estudiantes_admin.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/admin/versiones/modelo_versiones.dart';
import 'package:academiapp_v2/admin/versiones/repositorio_versiones_admin.dart';
import 'package:academiapp_v2/admin/versiones/versiones_page.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curriculo.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/entities/version_academica.dart';
import 'package:academiapp_v2/features/enrollment/domain/entities/matricula.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Domingo 1 nov 2026.
final hoy = DateTime(2026, 11, 1, 10);

// 2 cursos x 6 temas = 12 temas: lun-vie 3, sáb 2.
final curriculo = Curriculo(
  versionId: 'v1',
  areas: const [],
  cursos: const [
    Curso(id: 'a', areaId: 'x', nombre: 'Álgebra', orden: 1),
    Curso(id: 'f', areaId: 'x', nombre: 'Física', orden: 2),
  ],
  temas: [
    for (var i = 1; i <= 6; i++) ...[
      Tema(id: 'a$i', cursoId: 'a', titulo: 'Álgebra $i', orden: i),
      Tema(id: 'f$i', cursoId: 'f', titulo: 'Física $i', orden: i),
    ],
  ],
);

final version = VersionAcademica(
  id: 'v1',
  codigo: 'v1',
  nombre: 'Ciclo 2026-II',
  fechaApertura: DateTime(2026, 10, 26),
  estado: EstadoVersionAcademica.activa,
);

EstudianteAdmin alumno(
  String nombre,
  DateTime inicio, {
  EstadoMatricula estado = EstadoMatricula.activa,
}) => EstudianteAdmin(
  uid: nombre,
  nombre: nombre,
  correo: '$nombre@mail.pe',
  matricula: Matricula(
    id: 'm-$nombre',
    usuarioId: nombre,
    versionId: 'v1',
    fechaMatricula: inicio,
    fechaInicioAcademico: inicio,
    estado: estado,
  ),
);

final alumnos = [
  alumno('ana', DateTime(2026, 10, 26)), // lunes: hoy va en el día 6
  alumno('beto', DateTime(2026, 10, 28)),
  alumno('caro', DateTime(2026, 11, 3)), // programada
  alumno('dani', DateTime(2026, 10, 26), estado: EstadoMatricula.suspendida),
];

class Estudiantes implements RepositorioEstudiantesAdmin {
  @override
  Future<List<EstudianteAdmin>> estudiantes() async => alumnos;

  @override
  Future<List<VersionAcademica>> versiones() async => [version];

  @override
  Future<Curriculo> curriculo(String versionId) async => curriculo;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Versiones implements RepositorioVersionesAdmin {
  Set<String> ya = {'a1', 'f1', 'a2'};
  final publicaciones = <(int, List<String>)>[];

  @override
  Future<Set<String>> publicados(String versionId) async => ya;

  @override
  Future<void> publicar(
    String versionId, {
    required List<String> temas,
    required int dia,
  }) async {
    publicaciones.add((dia, temas));
    ya = {...ya, ...temas};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('reglas de versiones', () {
    final dias = calendarioVersion(curriculo, DateTime(2026, 10, 26));

    test('calendario: 3 temas de lunes a viernes, 2 el sábado', () {
      // 12 temas desde el lunes 26: cuatro días de 3.
      expect(dias.map((d) => d.temas.length), [3, 3, 3, 3]);
      expect(dias.first.temas, ['a1', 'f1', 'a2']);
      // Desde un viernes: vie 3, sáb 2, (dom libre), lun 3, mar 3, mié 1.
      final desdeViernes = calendarioVersion(curriculo, DateTime(2026, 10, 30));
      expect(desdeViernes.map((d) => d.temas.length), [3, 2, 3, 3, 1]);
    });

    test('estado de cada día y qué falta publicar', () {
      final publicados = {'a1', 'f1', 'a2'};
      expect(ultimoDiaPublicado(dias, publicados), 1);
      expect(estadoDia(dias[0], 2, publicados), EstadoDia.alcanzado);
      expect(estadoDia(dias[1], 2, publicados), EstadoDia.atrasado);
      expect(estadoDia(dias[2], 2, publicados), EstadoDia.pendiente);
      expect(temasPorPublicar(dias, 2, publicados), ['f2', 'a3', 'f3']);
    });

    test('conteo, más adelantado e inicios por fecha', () {
      final c = contarVersion('v1', alumnos, hoy);
      expect((c.activos, c.programados, c.suspendidos), (2, 1, 1));
      expect(inicioMasAdelantado('v1', alumnos), DateTime(2026, 10, 26));
      expect(iniciosPorFecha('v1', alumnos).first, (DateTime(2026, 10, 26), 2));
    });

    test('códigos de versión e ids copiados', () {
      expect(idDesdeNombre(' Ciclo 2027-I (Verano) '), 'ciclo-2027-i-verano');
      expect(
        idEnVersion('version-1__algebra-02__practica-1', 'version-1', 'c27'),
        'c27__algebra-02__practica-1',
      );
      expect(idEnVersion('suelto', 'version-1', 'c27'), 'c27__suelto');
    });
  });

  testWidgets(
    'versiones: publica hasta 2 días por delante del más adelantado',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final versiones = Versiones();
      await tester.pumpWidget(
        MaterialApp(
          theme: temaPanel(),
          home: Scaffold(
            body: VersionesPage(
              versiones: versiones,
              estudiantes: Estudiantes(),
              onVerEstudiantes: () {},
              ahora: () => hoy,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ciclo 2026-II'), findsWidgets);
      expect(find.text('Activa'), findsWidgets);
      // Ana empezó el lunes 26: hoy (domingo) va en el día 6; el temario
      // solo tiene 4 días, así que se publica todo.
      await tester.tap(find.text('Publicar hasta el día 4'));
      await tester.pumpAndSettle();

      expect(versiones.publicaciones.single.$1, 4);
      expect(versiones.publicaciones.single.$2.length, 9);
      expect(find.text('Publicado hasta el día 4'), findsOneWidget);
    },
  );
}
