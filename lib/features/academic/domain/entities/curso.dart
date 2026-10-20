class Curso {
  final String id;
  final String areaId;
  final String nombre;
  final int orden;
  final String? icono;
  final bool activo;

  const Curso({
    required this.id,
    required this.areaId,
    required this.nombre,
    required this.orden,
    this.icono,
    this.activo = true,
  });
}
