import 'package:academiapp_v2/core/presentation/texto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza para buscar sin tildes ni mayúsculas', () {
    expect(normalizarTexto('Álgebra Lineal'), 'algebra lineal');
    expect(normalizarTexto('Niño'), 'nino');
  });

  test('genera siglas para el ícono del curso', () {
    expect(siglas('Razonamiento Verbal'), 'RV');
    expect(siglas('Historia del Perú'), 'HP');
    expect(siglas('Lenguaje'), 'Le');
  });
}
