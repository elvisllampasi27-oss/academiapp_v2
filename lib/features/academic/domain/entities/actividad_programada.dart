enum TipoActividadProgramada { tema, reforzamiento }

enum EstadoActividadProgramada { preparada, publicada, archivada }

class ActividadProgramada {
  final String id;
  final String diaId;
  final String temaId;
  final int orden;
  final TipoActividadProgramada tipo;
  final EstadoActividadProgramada estado;

  const ActividadProgramada({
    required this.id,
    required this.diaId,
    required this.temaId,
    required this.orden,
    this.tipo = TipoActividadProgramada.tema,
    this.estado = EstadoActividadProgramada.preparada,
  });
}
