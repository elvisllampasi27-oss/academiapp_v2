class Respuesta {
  final String id;
  final String intentoId;
  final String preguntaId;
  final String opcionId;
  final bool esCorrecta;
  final Duration tiempoRespuesta;

  const Respuesta({
    required this.id,
    required this.intentoId,
    required this.preguntaId,
    required this.opcionId,
    required this.esCorrecta,
    required this.tiempoRespuesta,
  });
}
