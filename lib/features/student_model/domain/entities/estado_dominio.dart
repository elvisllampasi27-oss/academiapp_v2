enum NivelDominio { bajo, medio, alto }

class EstadoDominio {
  final String matriculaId;
  final String habilidadId;
  final double valor;
  final NivelDominio nivel;
  final String modeloVersion;
  final DateTime actualizadoEn;

  const EstadoDominio({
    required this.matriculaId,
    required this.habilidadId,
    required this.valor,
    required this.nivel,
    required this.modeloVersion,
    required this.actualizadoEn,
  });
}
