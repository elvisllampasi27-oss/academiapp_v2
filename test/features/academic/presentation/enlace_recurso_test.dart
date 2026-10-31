import 'package:academiapp_v2/features/academic/domain/entities/recurso.dart';
import 'package:academiapp_v2/features/academic/presentation/utils/enlace_recurso.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes_material.dart';

void main() {
  test('un ID de YouTube de V1 se convierte en enlace completo', () {
    final enlace = enlaceDeRecurso(recurso('r', ubicacion: 'AbCdEfGhIjK'));

    expect(enlace.toString(), 'https://www.youtube.com/watch?v=AbCdEfGhIjK');
  });

  test('acepta https y rechaza otros esquemas', () {
    expect(
      enlaceDeRecurso(
        recurso('r', tipo: TipoRecurso.pdf, ubicacion: 'https://a.pe/x.pdf'),
      ),
      isNotNull,
    );
    expect(
      enlaceDeRecurso(
        recurso('r', tipo: TipoRecurso.pdf, ubicacion: 'http://a.pe/x.pdf'),
      ),
      isNull,
    );
    expect(
      enlaceDeRecurso(recurso('r', ubicacion: 'javascript:alert(1)')),
      isNull,
    );
    expect(enlaceDeRecurso(recurso('r', ubicacion: '   ')), isNull);
  });
}
