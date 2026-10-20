import 'package:academiapp_v2/features/student_model/domain/entities/parametros_bkt.dart';
import 'package:academiapp_v2/features/student_model/domain/services/modelo_bkt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parametros = ParametrosBkt(
    conocimientoInicial: 0.20,
    aprendizaje: 0.10,
    adivinanza: 0.25,
    desliz: 0.10,
  );

  final service = ModeloBktService();

  test('aumenta la estimacion de conocimiento ante una respuesta correcta', () {
    final resultado = service.actualizarPorRespuesta(
      conocimientoActual: 0.20,
      respuestaCorrecta: true,
      parametros: parametros,
    );

    expect(resultado, closeTo(0.4737, 0.0001));
  });

  test(
    'disminuye la estimacion de conocimiento ante una respuesta incorrecta',
    () {
      final resultado = service.actualizarPorRespuesta(
        conocimientoActual: 0.20,
        respuestaCorrecta: false,
        parametros: parametros,
      );

      expect(resultado, closeTo(0.0323, 0.0001));
    },
  );

  test('aplica la probabilidad de aprendizaje despues de la respuesta', () {
    final resultado = service.aplicarAprendizaje(
      conocimientoPosterior: 0.4736842105,
      parametros: parametros,
    );

    expect(resultado, closeTo(0.5263, 0.0001));
  });

  test(
    'realiza una actualizacion BKT completa ante una respuesta correcta',
    () {
      final resultado = service.actualizarConocimiento(
        conocimientoActual: 0.20,
        respuestaCorrecta: true,
        parametros: parametros,
      );

      expect(resultado, closeTo(0.5263, 0.0001));
    },
  );
}
