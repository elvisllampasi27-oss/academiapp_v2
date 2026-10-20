class ResultadoEvaluacion {
  final int totalPreguntas;
  final int respuestasCorrectas;
  final int respuestasIncorrectas;
  final double puntaje;

  const ResultadoEvaluacion({
    required this.totalPreguntas,
    required this.respuestasCorrectas,
    required this.respuestasIncorrectas,
    required this.puntaje,
  });
}
