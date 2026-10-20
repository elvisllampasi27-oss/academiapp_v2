import 'respuesta.dart';
import 'resultado_evaluacion.dart';

class CalcularResultadoEvaluacionService {
  const CalcularResultadoEvaluacionService();

  ResultadoEvaluacion calcular(List<Respuesta> respuestas) {
    if (respuestas.isEmpty) {
      return const ResultadoEvaluacion(
        totalPreguntas: 0,
        respuestasCorrectas: 0,
        respuestasIncorrectas: 0,
        puntaje: 0,
      );
    }

    final correctas = respuestas
        .where((respuesta) => respuesta.esCorrecta)
        .length;

    final incorrectas = respuestas.length - correctas;

    final puntaje = (correctas / respuestas.length) * 100;

    return ResultadoEvaluacion(
      totalPreguntas: respuestas.length,
      respuestasCorrectas: correctas,
      respuestasIncorrectas: incorrectas,
      puntaje: puntaje,
    );
  }
}
