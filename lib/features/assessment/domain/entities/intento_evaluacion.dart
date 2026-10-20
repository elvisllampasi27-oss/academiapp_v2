enum EstadoIntentoEvaluacion { enProgreso, completado, cancelado }

class IntentoEvaluacion {
  final String id;
  final String matriculaId;
  final String evaluacionId;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final double? puntaje;
  final EstadoIntentoEvaluacion estado;

  const IntentoEvaluacion({
    required this.id,
    required this.matriculaId,
    required this.evaluacionId,
    required this.fechaInicio,
    required this.estado,
    this.fechaFin,
    this.puntaje,
  });
}
