import 'dart:convert';
import 'dart:io';

import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/services/calendario_academico_service.dart';
import 'package:academiapp_v2/features/academic/domain/services/secuencia_academica_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final datos = jsonDecode(
    File('tool/curriculo_v1.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final areas = (datos['areas'] as List).cast<Map<String, dynamic>>();

  final cursos = (datos['cursos'] as List)
      .cast<Map<String, dynamic>>()
      .map(
        (c) => Curso(
          id: c['id'] as String,
          areaId: c['areaId'] as String,
          nombre: c['nombre'] as String,
          orden: c['orden'] as int,
          icono: c['icono'] as String?,
        ),
      )
      .toList();

  final temas = (datos['temas'] as List)
      .cast<Map<String, dynamic>>()
      .map(
        (t) => Tema(
          id: t['id'] as String,
          cursoId: t['cursoId'] as String,
          titulo: t['titulo'] as String,
          orden: t['orden'] as int,
        ),
      )
      .toList();

  test('el curriculo migrado tiene 6 areas, 17 cursos y 205 temas', () {
    expect(areas.length, 6);
    expect(cursos.length, 17);
    expect(temas.length, 205);
  });

  test('los IDs son unicos y las referencias existen', () {
    final idsAreas = areas.map((a) => a['id'] as String).toSet();
    final idsCursos = cursos.map((c) => c.id).toSet();

    expect(idsAreas.length, areas.length);
    expect(idsCursos.length, cursos.length);
    expect(temas.map((t) => t.id).toSet().length, temas.length);
    expect(cursos.map((c) => c.orden).toSet().length, cursos.length);

    for (final curso in cursos) {
      expect(idsAreas, contains(curso.areaId));
    }
    for (final tema in temas) {
      expect(idsCursos, contains(tema.cursoId));
    }
  });

  test('la secuencia real recorre los 17 cursos por rondas', () {
    final secuencia = const SecuenciaAcademicaService().generar(
      cursos: cursos,
      temas: temas,
    );

    expect(secuencia.length, 205);
    expect(secuencia.take(3).map((t) => t.id).toList(), [
      'razonamiento_verbal-01',
      'lenguaje-01',
      'literatura-01',
    ]);
    expect(secuencia[17].id, 'razonamiento_verbal-02');
    expect(secuencia.last.id, 'anatomia-13');
  });

  test('el calendario Dart coincide con el que publica el script', () {
    final secuencia = const SecuenciaAcademicaService().generar(
      cursos: cursos,
      temas: temas,
    );

    final dias = const CalendarioAcademicoService().generar(
      secuencia: secuencia,
      fechaInicio: DateTime(2026, 10, 23),
    );

    // Mismos valores que verifica tool/test/seed_academico_v2.test.js.
    expect(dias.length, 73);
    expect(dias[5].fecha, DateTime(2026, 10, 29));
    expect(dias[5].actividades.map((a) => a.temaId).toList(), [
      'geografia-01',
      'formacion_civica-01',
      'razonamiento_matematico-01',
    ]);
    expect(dias.take(8).expand((d) => d.actividades).length, 22);
  });
}
