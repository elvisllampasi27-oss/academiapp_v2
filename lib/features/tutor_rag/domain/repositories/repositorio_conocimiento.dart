import '../entities/chunk_conocimiento.dart';
import '../entities/embedding_chunk.dart';

abstract class RepositorioConocimiento {
  Future<List<ChunkConocimiento>> obtenerChunks();

  Future<List<EmbeddingChunk>> obtenerEmbeddings();
}
