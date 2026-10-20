import 'package:academiapp_v2/features/tutor_rag/domain/entities/documento_conocimiento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permite usar en RAG un documento validado', () {
    final documento = DocumentoConocimiento(
      id: 'documento-1',
      recursoId: 'recurso-1',
      versionId: 'v2',
      titulo: 'Introduccion a matrices',
      tipo: TipoDocumentoConocimiento.pdf,
      estado: EstadoDocumentoConocimiento.validado,
      fechaValidacion: DateTime(2026, 10, 20),
    );

    expect(documento.puedeUsarseEnRag, isTrue);
  });

  test('no permite usar en RAG un documento pendiente', () {
    const documento = DocumentoConocimiento(
      id: 'documento-1',
      recursoId: 'recurso-1',
      versionId: 'v2',
      titulo: 'Introduccion a matrices',
      tipo: TipoDocumentoConocimiento.pdf,
      estado: EstadoDocumentoConocimiento.pendiente,
    );

    expect(documento.puedeUsarseEnRag, isFalse);
  });

  test('no permite usar en RAG un documento archivado', () {
    final documento = DocumentoConocimiento(
      id: 'documento-1',
      recursoId: 'recurso-1',
      versionId: 'v2',
      titulo: 'Introduccion a matrices',
      tipo: TipoDocumentoConocimiento.pdf,
      estado: EstadoDocumentoConocimiento.archivado,
      fechaValidacion: DateTime(2026, 10, 20),
    );

    expect(documento.puedeUsarseEnRag, isFalse);
  });
}
