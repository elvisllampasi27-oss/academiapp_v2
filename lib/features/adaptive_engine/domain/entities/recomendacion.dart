enum TipoRecomendacion { reforzar, practicar, profundizar }

enum EstadoRecomendacion { pendiente, completada, descartada }

class Recomendacion {
  final String id;
  final String matriculaId;
  final String habilidadId;
  final TipoRecomendacion tipo;
  final String motivo;
  final int prioridad;
  final DateTime fecha;
  final EstadoRecomendacion estado;

  const Recomendacion({
    required this.id,
    required this.matriculaId,
    required this.habilidadId,
    required this.tipo,
    required this.motivo,
    required this.prioridad,
    required this.fecha,
    this.estado = EstadoRecomendacion.pendiente,
  });
}
