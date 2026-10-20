enum DificultadPregunta { basica, intermedia, avanzada }

class Pregunta {
  final String id;
  final String evaluacionId;
  final String enunciado;
  final String? explicacion;
  final DificultadPregunta dificultad;
  final bool activa;

  const Pregunta({
    required this.id,
    required this.evaluacionId,
    required this.enunciado,
    required this.dificultad,
    this.explicacion,
    this.activa = true,
  });
}
