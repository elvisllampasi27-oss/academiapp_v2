class Opcion {
  final String id;
  final String preguntaId;
  final String texto;
  final bool esCorrecta;

  const Opcion({
    required this.id,
    required this.preguntaId,
    required this.texto,
    required this.esCorrecta,
  });
}
