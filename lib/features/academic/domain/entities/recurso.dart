enum TipoRecurso { video, pdf, teoria, ejemplo, ejercicio, grabacion }

class Recurso {
  final String id;
  final String temaId;
  final String versionId;
  final TipoRecurso tipo;
  final String titulo;
  final String ubicacion;
  final bool activo;
  final String? reemplazaA;

  const Recurso({
    required this.id,
    required this.temaId,
    required this.versionId,
    required this.tipo,
    required this.titulo,
    required this.ubicacion,
    this.activo = true,
    this.reemplazaA,
  });
}
