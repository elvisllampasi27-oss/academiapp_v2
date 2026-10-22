import 'package:academiapp_v2/features/tutor_rag/domain/services/similitud_coseno_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = SimilitudCosenoService();

  test('vectores iguales tienen similitud cercana a 1', () {
    final similitud = service.calcular(
      vectorA: [1.0, 2.0, 3.0],
      vectorB: [1.0, 2.0, 3.0],
    );

    expect(similitud, closeTo(1.0, 0.0001));
  });

  test('vectores ortogonales tienen similitud 0', () {
    final similitud = service.calcular(
      vectorA: [1.0, 0.0],
      vectorB: [0.0, 1.0],
    );

    expect(similitud, closeTo(0.0, 0.0001));
  });

  test('rechaza vectores con dimensiones diferentes', () {
    expect(
      () => service.calcular(vectorA: [1.0, 2.0], vectorB: [1.0, 2.0, 3.0]),
      throwsArgumentError,
    );
  });

  test('un vector cero produce similitud 0', () {
    final similitud = service.calcular(
      vectorA: [0.0, 0.0],
      vectorB: [1.0, 1.0],
    );

    expect(similitud, 0.0);
  });
}
