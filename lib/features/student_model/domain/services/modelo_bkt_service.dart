import '../entities/parametros_bkt.dart';

class ModeloBktService {
  double actualizarPorRespuesta({
    required double conocimientoActual,
    required bool respuestaCorrecta,
    required ParametrosBkt parametros,
  }) {
    if (respuestaCorrecta) {
      final numerador = conocimientoActual * (1 - parametros.desliz);

      final denominador =
          numerador + (1 - conocimientoActual) * parametros.adivinanza;

      return numerador / denominador;
    }

    final numerador = conocimientoActual * parametros.desliz;

    final denominador =
        numerador + (1 - conocimientoActual) * (1 - parametros.adivinanza);

    return numerador / denominador;
  }

  double aplicarAprendizaje({
    required double conocimientoPosterior,
    required ParametrosBkt parametros,
  }) {
    return conocimientoPosterior +
        (1 - conocimientoPosterior) * parametros.aprendizaje;
  }

  double actualizarConocimiento({
    required double conocimientoActual,
    required bool respuestaCorrecta,
    required ParametrosBkt parametros,
  }) {
    final conocimientoPosterior = actualizarPorRespuesta(
      conocimientoActual: conocimientoActual,
      respuestaCorrecta: respuestaCorrecta,
      parametros: parametros,
    );

    return aplicarAprendizaje(
      conocimientoPosterior: conocimientoPosterior,
      parametros: parametros,
    );
  }
}
