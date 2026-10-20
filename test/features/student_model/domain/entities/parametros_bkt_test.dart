import 'package:academiapp_v2/features/student_model/domain/entities/parametros_bkt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta parametros BKT entre cero y uno', () {
    expect(
      () => const ParametrosBkt(
        conocimientoInicial: 0.20,
        aprendizaje: 0.10,
        adivinanza: 0.25,
        desliz: 0.10,
      ),
      returnsNormally,
    );
  });

  test('rechaza parametros BKT fuera del rango permitido', () {
    expect(
      () => ParametrosBkt(
        conocimientoInicial: 1.20,
        aprendizaje: 0.10,
        adivinanza: 0.25,
        desliz: 0.10,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
