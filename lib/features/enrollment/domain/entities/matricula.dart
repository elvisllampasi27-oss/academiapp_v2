enum EstadoMatricula { programada, activa, finalizada, suspendida }

class Matricula {
  final String id;
  final String usuarioId;
  final String versionId;

  final DateTime fechaMatricula;
  final DateTime fechaInicioAcademico;
  final DateTime? fechaFin;

  final EstadoMatricula estado;

  const Matricula({
    required this.id,
    required this.usuarioId,
    required this.versionId,
    required this.fechaMatricula,
    required this.fechaInicioAcademico,
    required this.estado,
    this.fechaFin,
  });
}
