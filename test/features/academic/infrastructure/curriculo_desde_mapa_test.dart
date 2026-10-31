import 'package:academiapp_v2/features/academic/infrastructure/repositories/repositorio_curriculo_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convierte el documento del temario en entidades', () {
    final curriculo = curriculoDesdeMapa('version-1', {
      'areas': [
        {'id': 'matematica', 'nombre': 'Matemática', 'orden': 2},
        {'id': 'comunicacion', 'nombre': 'Comunicación', 'orden': 1},
      ],
      'cursos': [
        {
          'id': 'algebra',
          'areaId': 'matematica',
          'nombre': 'Álgebra',
          'orden': 5,
          'icono': null,
        },
      ],
      'temas': [
        {
          'id': 'algebra-02',
          'cursoId': 'algebra',
          'titulo': 'Polinomios',
          'orden': 2,
          'descripcion': null,
        },
        {
          'id': 'algebra-01',
          'cursoId': 'algebra',
          'titulo': 'Teoría de exponentes',
          'orden': 1,
          'descripcion': null,
        },
      ],
    });

    expect(curriculo.areas.map((a) => a.id), ['comunicacion', 'matematica']);
    expect(curriculo.cursos.single.nombre, 'Álgebra');
    expect(curriculo.temasDe('algebra').map((t) => t.id), [
      'algebra-01',
      'algebra-02',
    ]);
    expect(curriculo.area('matematica')?.nombre, 'Matemática');
  });
}
