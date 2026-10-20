import 'package:academiapp_v2/features/tutor_rag/domain/entities/chunk_conocimiento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un chunk conserva el documento y contenido de origen', () {
    const chunk = ChunkConocimiento(
      id: 'chunk-3',
      documentoId: 'documento-matrices',
      contenido: 'Para sumar matrices deben tener el mismo orden.',
      orden: 3,
    );

    expect(chunk.id, 'chunk-3');
    expect(chunk.documentoId, 'documento-matrices');
    expect(chunk.contenido, 'Para sumar matrices deben tener el mismo orden.');
    expect(chunk.orden, 3);
  });
}
