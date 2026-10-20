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
      fechaInicio: DateTime(2026, 10, 19), // lunes
    );

    expect(dias.length, 6);

    expect(dias[0].temas.length, 3);
    expect(dias[1].temas.length, 3);
    expect(dias[2].temas.length, 3);
    expect(dias[3].temas.length, 3);
    expect(dias[4].temas.length, 3);
    expect(dias[5].temas.length, 2);

    expect(dias[5].fecha?.weekday, DateTime.saturday);
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
      fechaInicio: DateTime(2026, 10, 23), // viernes
    );

    expect(dias[0].fecha, DateTime(2026, 10, 23));
    expect(dias[0].temas.length, 3);

    expect(dias[1].fecha, DateTime(2026, 10, 24));
    expect(dias[1].temas.length, 2);

    // Domingo 25 no debe aparecer.
    expect(dias[2].fecha, DateTime(2026, 10, 26));
    expect(dias[2].temas.length, 3);
  });
}
