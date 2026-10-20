import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/services/calendario_academico_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CalendarioAcademicoService();

  test('distribuye 17 temas en 6 dias academicos', () {
    final temas = List.generate(
      17,
      (index) => Tema(
        id: 'tema-${index + 1}',
        cursoId: 'curso',
        titulo: 'Tema ${index + 1}',
        orden: index + 1,
      ),
    );

    final dias = service.generar(temas);

    expect(dias.length, 6);

    expect(dias[0].temas.length, 3);
    expect(dias[1].temas.length, 3);
    expect(dias[2].temas.length, 3);
    expect(dias[3].temas.length, 3);
    expect(dias[4].temas.length, 3);
    expect(dias[5].temas.length, 2);

    expect(
      dias.expand((dia) => dia.temas).map((tema) => tema.id).toList(),
      List.generate(17, (index) => 'tema-${index + 1}'),
    );
  });
}
