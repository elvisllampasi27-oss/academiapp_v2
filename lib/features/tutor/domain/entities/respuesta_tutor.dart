class RespuestaTutor {
  final String texto;

  /// Dudas que le quedan hoy al estudiante (null si no hay límite).
  final int? restantesHoy;
  final int? limiteDiario;

  const RespuestaTutor({
    required this.texto,
    this.restantesHoy,
    this.limiteDiario,
  });
}
