class ConocimientoNoEncontradoException implements Exception {
  final String mensaje;

  const ConocimientoNoEncontradoException([
    this.mensaje =
        'No se encontro conocimiento validado para responder la consulta.',
  ]);

  @override
  String toString() => mensaje;
}
