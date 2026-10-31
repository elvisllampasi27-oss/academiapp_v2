/// Cuánto de la clase (video) de un tema vio el estudiante.
class ProgresoClase {
  final String temaId;
  final String versionId;

  /// Partes vistas de corrido, en segundos: (desde, hasta), ordenadas.
  final List<(double, double)> tramos;
  final double duracion;
  final bool completada;

  const ProgresoClase({
    required this.temaId,
    required this.versionId,
    required this.tramos,
    required this.duracion,
    required this.completada,
  });
}
