enum TipoEvaluacion { practica, evaluacionTema, simulacro }

enum EstadoEvaluacion { borrador, publicada, archivada }

class Evaluacion {
  final String id;
  final String temaId;
  final String versionId;
  final TipoEvaluacion tipo;
  final String? nivel;
  final EstadoEvaluacion estado;

  const Evaluacion({
    required this.id,
    required this.temaId,
    required this.versionId,
    required this.tipo,
    required this.estado,
    this.nivel,
  });
}
