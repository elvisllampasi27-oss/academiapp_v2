class Habilidad {
  final String id;
  final String contenidoId;
  final String nombre;
  final String? descripcion;
  final bool activa;

  const Habilidad({
    required this.id,
    required this.contenidoId,
    required this.nombre,
    this.descripcion,
    this.activa = true,
  });
}
