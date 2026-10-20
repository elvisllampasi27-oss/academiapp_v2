class Contenido {
  final String id;
  final String temaId;
  final String nombre;
  final String? descripcion;
  final int orden;
  final bool activo;

  const Contenido({
    required this.id,
    required this.temaId,
    required this.nombre,
    required this.orden,
    this.descripcion,
    this.activo = true,
  });
}
