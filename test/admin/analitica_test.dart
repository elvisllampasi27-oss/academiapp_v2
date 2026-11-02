import 'package:academiapp_v2/admin/analitica/analitica_page.dart';
import 'package:academiapp_v2/admin/analitica/modelo_analitica.dart';
import 'package:academiapp_v2/admin/estudiantes/modelo_estudiantes.dart';
import 'package:academiapp_v2/admin/estudiantes/repositorio_estudiantes_admin.dart';
import 'package:academiapp_v2/admin/pagos/repositorio_pagos_admin.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/enrollment/domain/entities/matricula.dart';
import 'package:academiapp_v2/features/premium/domain/pago.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final hoy = DateTime(2026, 11, 2, 10);

EstudianteAdmin estudiante(
  String nombre, {
  String? carrera,
  DateTime? registro,
  DateTime? ultima,
  bool matriculado = true,
  DateTime? premiumHasta,
}) => EstudianteAdmin(
  uid: nombre,
  nombre: nombre,
  correo: '$nombre@mail.pe',
  carrera: carrera,
  registro: registro,
  ultimaActividad: ultima,
  premiumHasta: premiumHasta,
  matricula: matriculado
      ? Matricula(
          id: 'm-$nombre',
          usuarioId: nombre,
          versionId: 'v1',
          fechaMatricula: DateTime(2026, 10, 20),
          fechaInicioAcademico: DateTime(2026, 10, 21),
          estado: EstadoMatricula.activa,
        )
      : null,
);

Pago pago(
  int monto,
  DateTime aprobado, {
  EstadoPago estado = EstadoPago.aprobado,
}) => Pago(
  id: 'p$monto${aprobado.month}',
  usuarioId: 'u',
  nombre: 'U',
  correo: 'u@mail.pe',
  monto: monto,
  metodo: MetodoPago.yape,
  operacion: '123456',
  estado: estado,
  creadoEn: aprobado.subtract(const Duration(days: 1)),
  revisadoEn: aprobado,
);

final estudiantes = [
  estudiante(
    'ana',
    carrera: 'Medicina',
    registro: DateTime(2026, 11, 1),
    ultima: DateTime(2026, 11, 2),
    premiumHasta: DateTime(2026, 12, 1),
  ),
  estudiante(
    'beto',
    carrera: 'Medicina',
    registro: DateTime(2026, 10, 5),
    ultima: DateTime(2026, 10, 1),
  ),
  estudiante('caro', carrera: 'Derecho', registro: DateTime(2026, 10, 8)),
  estudiante('dani', matriculado: false, registro: DateTime(2026, 9, 9)),
];

class FalsoEstudiantes implements RepositorioEstudiantesAdmin {
  @override
  Future<List<EstudianteAdmin>> estudiantes() async => _estudiantesDePrueba;

  @override
  Future<List<ActividadDia>> actividadReciente({int dias = 14}) async => [
    for (var i = dias - 1; i >= 0; i--)
      ActividadDia(DateTime(hoy.year, hoy.month, hoy.day - i), i % 3, 0),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _estudiantesDePrueba = estudiantes;

class FalsoPagos implements RepositorioPagosAdmin {
  @override
  Future<List<Pago>> pagos(EstadoPago estado) async => [
    pago(29, DateTime(2026, 11, 1)),
    pago(29, DateTime(2026, 10, 15)),
    pago(49, DateTime(2026, 10, 20)),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('ingresos y registros por mes, del más antiguo al actual', () {
    final ingresos = ingresosPorMes(
      [
        pago(29, DateTime(2026, 11, 1)),
        pago(49, DateTime(2026, 10, 20)),
        pago(99, DateTime(2026, 11, 1), estado: EstadoPago.rechazado),
        pago(15, DateTime(2025, 11, 1)), // hace un año: fuera
      ],
      hoy,
      meses: 3,
    );
    expect(
      [for (final (m, n) in ingresos) '${m.month}:$n'],
      ['9:0', '10:49', '11:29'],
    );
    expect(variacion(ingresos), '−41 %');

    final registros = registrosPorMes(estudiantes, hoy, meses: 3);
    expect([for (final (_, n) in registros) n], [1, 2, 1]);
  });

  test('carreras, situación y retención', () {
    expect(porCarrera(estudiantes), [
      ('Medicina', 2),
      ('Derecho', 1),
      ('Sin carrera', 1),
    ]);
    expect(porCarrera(estudiantes, maximo: 2), [('Medicina', 2), ('Otras', 2)]);
    expect(porSituacion(estudiantes, hoy)[SituacionEstudiante.activo], 3);
    // De 3 activos, solo Ana entró en los últimos 7 días.
    expect(retencion(estudiantes, hoy), closeTo(1 / 3, 0.001));
    expect(retencion(const [], hoy), isNull);
    expect(variacion(const []), isNull);
  });

  testWidgets('analítica: muestra las cifras', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: AnaliticaPage(
            estudiantes: FalsoEstudiantes(),
            pagos: FalsoPagos(),
            onVerEstudiantes: (_) {},
            ahora: () => hoy,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estudiantes registrados'), findsOneWidget);
    expect(find.text('S/ 29'), findsOneWidget);
    expect(find.text('Medicina'), findsOneWidget);
    expect(find.text('33 %'), findsOneWidget);
  });
}
