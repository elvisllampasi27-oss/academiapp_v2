import 'package:academiapp_v2/features/tutor_rag/domain/entities/chunk_conocimiento.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/embedding_chunk.dart';
import 'package:academiapp_v2/features/tutor_rag/infrastructure/repositories/repositorio_conocimiento_en_memoria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repositorio entrega chunks y embeddings almacenados', () async {
    const repositorio = RepositorioConocimientoEnMemoria(
      chunks: [
        ChunkConocimiento(
          id: 'chunk-1',
          documentoId: 'doc-1',
          contenido: 'Para sumar matrices deben tener las mismas dimensiones.',
          orden: 1,
        ),
      ],
      embeddings: [
        EmbeddingChunk(chunkId: 'chunk-1', vector: [0.9, 0.2, 0.8]),
      ],
    );

    final chunks = await repositorio.obtenerChunks();
    final embeddings = await repositorio.obtenerEmbeddings();

    expect(chunks.length, 1);
    expect(chunks.first.id, 'chunk-1');

    expect(embeddings.length, 1);
    expect(embeddings.first.chunkId, 'chunk-1');
  });
}
