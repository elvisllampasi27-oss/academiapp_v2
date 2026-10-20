enum TipoDocumentoConocimiento { video, pdf, texto, material }

enum EstadoDocumentoConocimiento { pendiente, validado, archivado }

class DocumentoConocimiento {
  final String id;
  final String recursoId;
  final String versionId;
  final String titulo;
  final TipoDocumentoConocimiento tipo;
  final EstadoDocumentoConocimiento estado;
  final DateTime? fechaValidacion;

  const DocumentoConocimiento({
    required this.id,
    required this.recursoId,
    required this.versionId,
    required this.titulo,
    required this.tipo,
    required this.estado,
    this.fechaValidacion,
  });

  bool get puedeUsarseEnRag =>
      estado == EstadoDocumentoConocimiento.validado && fechaValidacion != null;
}
