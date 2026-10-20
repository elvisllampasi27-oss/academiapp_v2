class Tema {
  final String id;
  final String cursoId;
  final String titulo;
  final int orden;
  final String? descripcion;
  final bool activo;

  const Tema({
    required this.id,
    required this.cursoId,
    required this.titulo,
    required this.orden,
    this.descripcion,
    this.activo = true,
  });
}
