import 'dart:math' as math;

class SimilitudCosenoService {
  const SimilitudCosenoService();

  double calcular({
    required List<double> vectorA,
    required List<double> vectorB,
  }) {
    if (vectorA.isEmpty || vectorB.isEmpty) {
      throw ArgumentError('Los vectores no pueden estar vacios.');
    }

    if (vectorA.length != vectorB.length) {
      throw ArgumentError('Los vectores deben tener la misma dimension.');
    }

    var productoPunto = 0.0;
    var magnitudA = 0.0;
    var magnitudB = 0.0;

    for (var i = 0; i < vectorA.length; i++) {
      productoPunto += vectorA[i] * vectorB[i];
      magnitudA += vectorA[i] * vectorA[i];
      magnitudB += vectorB[i] * vectorB[i];
    }

    if (magnitudA == 0 || magnitudB == 0) {
      return 0;
    }

    return productoPunto / (math.sqrt(magnitudA) * math.sqrt(magnitudB));
  }
}
