import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/services/calendario_academico_service.dart';
import 'package:academiapp_v2/features/academic/domain/services/semana_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 40 temas desde el lunes 19 de octubre de 2026: 17 por semana.
  final temas = List.generate(
    40,
    (i) => Tema(id: 't${i + 1}', cursoId: 'c', titulo: 'T${i + 1}', orden: i),
  );
  final inicio = DateTime(2026, 10, 19);
  final calendario = const CalendarioAcademicoService().generar(
    secuencia: temas,
    fechaInicio: inicio,
  );
  final todos = {for (final t in temas) t.id};

  test('la semana de hoy: sus 17 temas y su sábado', () {
    final s = semanaDelCalendario(
      calendario: calendario,
      fechaInicio: inicio,
      hoy: DateTime(2026, 10, 28, 15),
      publicados: todos,
    )!;
    expect(s.numero, 2);
    expect(s.temaIds.length, 17);
    expect(s.temaIds.first, 't18');
    expect(s.temaIds.last, 't34');
    expect(s.sabado, DateTime(2026, 10, 31));
  });

  test('solo cuenta los temas publicados', () {
    final s = semanaDelCalendario(
      calendario: calendario,
      fechaInicio: inicio,
      hoy: DateTime(2026, 10, 19),
      publicados: {'t1', 't2', 't30'},
    )!;
    expect(s.temaIds, ['t1', 't2']);
  });

  test('antes de empezar no hay semana', () {
    expect(
      semanaDelCalendario(
        calendario: calendario,
        fechaInicio: inicio,
        hoy: DateTime(2026, 10, 18),
        publicados: todos,
      ),
      isNull,
    );
  });

  test('próximos 7 días: desde hoy, con sus temas publicados', () {
    final dias = proximosDiasDelCalendario(
      calendario: calendario,
      hoy: DateTime(2026, 10, 30, 9),
      publicados: {'t29', 't30', 't35'},
    );
    // Viernes 30, sábado 31, (domingo no), lunes 2 y martes 3: ahí se
    // acaban los 40 temas del plan.
    expect(dias.first.fecha, DateTime(2026, 10, 30));
    expect(dias.last.fecha, DateTime(2026, 11, 3));
    expect(dias.length, 4);
    expect(dias.first.actividades.map((a) => a.temaId), ['t30']);
    expect(dias[2].actividades.map((a) => a.temaId), ['t35']);
  });
}
