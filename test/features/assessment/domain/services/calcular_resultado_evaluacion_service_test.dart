import 'package:academiapp_v2/features/assessment/domain/entities/respuesta.dart';
import 'package:academiapp_v2/features/assessment/domain/services/calcular_resultado_evaluacion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CalcularResultadoEvaluacionService();

  Respuesta crearRespuesta({required String id, required bool esCorrecta}) {
    return Respuesta(
      id: id,
      intentoId: 'intento-1',
      preguntaId: 'pregunta-$id',
      opcionId: 'opcion-$id',
      esCorrecta: esCorrecta,
      tiempoRespuesta: const Duration(seconds: 20),
    );
  }

  test('calcula correctamente el resultado de una evaluacion', () {
    final respuestas = [
      crearRespuesta(id: '1', esCorrecta: true),
      crearRespuesta(id: '2', esCorrecta: false),
      crearRespuesta(id: '3', esCorrecta: true),
      crearRespuesta(id: '4', esCorrecta: true),
      crearRespuesta(id: '5', esCorrecta: false),
    ];

    final resultado = service.calcular(respuestas);

    expect(resultado.totalPreguntas, 5);
    expect(resultado.respuestasCorrectas, 3);
    expect(resultado.respuestasIncorrectas, 2);
    expect(resultado.puntaje, 60);
  });

  test('devuelve puntaje perfecto cuando todas son correctas', () {
    final respuestas = [
      crearRespuesta(id: '1', esCorrecta: true),
      crearRespuesta(id: '2', esCorrecta: true),
      crearRespuesta(id: '3', esCorrecta: true),
    ];

    final resultado = service.calcular(respuestas);

    expect(resultado.respuestasCorrectas, 3);
    expect(resultado.respuestasIncorrectas, 0);
    expect(resultado.puntaje, 100);
  });

  test('maneja una evaluacion sin respuestas', () {
    final resultado = service.calcular([]);

    expect(resultado.totalPreguntas, 0);
    expect(resultado.respuestasCorrectas, 0);
    expect(resultado.respuestasIncorrectas, 0);
    expect(resultado.puntaje, 0);
  });
}
