import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/services/calendario_academico_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CalendarioAcademicoService();

  test('distribuye 17 temas de lunes a sabado', () {
    final temas = List.generate(
      17,
      (index) => Tema(
        id: 'tema-${index + 1}',
        cursoId: 'curso',
        titulo: 'Tema ${index + 1}',
        orden: index + 1,
      ),
    );

    final dias = service.generar(
      secuencia: temas,
      fechaInicio: DateTime(2026, 10, 19),
    );

    expect(dias.length, 6);

    expect(dias[0].actividades.length, 3);
    expect(dias[1].actividades.length, 3);
    expect(dias[2].actividades.length, 3);
    expect(dias[3].actividades.length, 3);
    expect(dias[4].actividades.length, 3);
    expect(dias[5].actividades.length, 2);

    expect(dias[5].fecha?.weekday, DateTime.saturday);

    expect(dias[0].actividades[0].temaId, 'tema-1');
    expect(dias[0].actividades[1].temaId, 'tema-2');
    expect(dias[0].actividades[2].temaId, 'tema-3');
  });

  test('si inicia viernes respeta sabado y omite domingo', () {
    final temas = List.generate(
      10,
      (index) => Tema(
        id: 'tema-${index + 1}',
        cursoId: 'curso',
        titulo: 'Tema ${index + 1}',
        orden: index + 1,
      ),
    );

    final dias = service.generar(
      secuencia: temas,
      fechaInicio: DateTime(2026, 10, 23),
    );

    expect(dias[0].fecha, DateTime(2026, 10, 23));
    expect(dias[0].actividades.length, 3);

    expect(dias[1].fecha, DateTime(2026, 10, 24));
    expect(dias[1].actividades.length, 2);

    expect(dias[2].fecha, DateTime(2026, 10, 26));
    expect(dias[2].actividades.length, 3);
  });

  test('crea actividades con orden y referencia al tema', () {
    final temas = List.generate(
      3,
      (index) => Tema(
        id: 'tema-${index + 1}',
        cursoId: 'curso',
        titulo: 'Tema ${index + 1}',
        orden: index + 1,
      ),
    );

    final dias = service.generar(
      secuencia: temas,
      fechaInicio: DateTime(2026, 10, 19),
    );

    final actividades = dias.first.actividades;

    expect(actividades[0].orden, 1);
    expect(actividades[0].temaId, 'tema-1');
    expect(actividades[0].diaId, 'dia-1');

    expect(actividades[1].orden, 2);
    expect(actividades[1].temaId, 'tema-2');

    expect(actividades[2].orden, 3);
    expect(actividades[2].temaId, 'tema-3');
  });
}
