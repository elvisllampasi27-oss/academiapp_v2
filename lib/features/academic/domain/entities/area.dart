class Area {
  final String id;
  final String nombre;
  final int orden;
  final bool activa;

  const Area({
    required this.id,
    required this.nombre,
    required this.orden,
    this.activa = true,
  });
}
