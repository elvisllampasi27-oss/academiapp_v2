enum EstadoSeminario { proximo, enVivo, grabado }

/// Repaso complementario por YouTube. El mismo enlace sirve para el vivo
/// y, al terminar, para la grabación (YouTube la guarda sola).
class Seminario {
  final String id;
  final String titulo;
  final String? curso;
  final DateTime fecha;
  final String videoId;
  final int duracionMinutos;

  const Seminario({
    required this.id,
    required this.titulo,
    required this.fecha,
    required this.videoId,
    this.curso,
    this.duracionMinutos = 90,
  });

  DateTime get fin => fecha.add(Duration(minutes: duracionMinutos));

  EstadoSeminario estado(DateTime ahora) {
    if (ahora.isBefore(fecha)) return EstadoSeminario.proximo;
    if (ahora.isBefore(fin)) return EstadoSeminario.enVivo;
    return EstadoSeminario.grabado;
  }

  Uri get enlace => Uri.https('www.youtube.com', '/watch', {'v': videoId});
}

abstract class RepositorioSeminarios {
  Future<List<Seminario>> listar();
}
