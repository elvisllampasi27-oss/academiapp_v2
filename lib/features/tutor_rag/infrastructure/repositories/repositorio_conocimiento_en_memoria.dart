import '../../domain/entities/chunk_conocimiento.dart';
import '../../domain/entities/embedding_chunk.dart';
import '../../domain/repositories/repositorio_conocimiento.dart';

class RepositorioConocimientoEnMemoria implements RepositorioConocimiento {
  final List<ChunkConocimiento> chunks;
  final List<EmbeddingChunk> embeddings;

  const RepositorioConocimientoEnMemoria({
    required this.chunks,
    required this.embeddings,
  });

  @override
  Future<List<ChunkConocimiento>> obtenerChunks() async {
    return List.unmodifiable(chunks);
  }

  @override
  Future<List<EmbeddingChunk>> obtenerEmbeddings() async {
    return List.unmodifiable(embeddings);
  }
}
