class PlanAcademico {
  final String id;
  final String versionId;
  final String nombre;
  final bool activo;

  const PlanAcademico({
    required this.id,
    required this.versionId,
    required this.nombre,
    this.activo = true,
  });
}
