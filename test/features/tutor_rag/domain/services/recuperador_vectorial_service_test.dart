import 'package:academiapp_v2/features/tutor_rag/domain/entities/chunk_conocimiento.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/embedding_chunk.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/repositories/repositorio_conocimiento.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/repositories/generador_embedding.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/services/recuperador_vectorial_service.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/services/similitud_coseno_service.dart';
import 'package:flutter_test/flutter_test.dart';

class GeneradorEmbeddingFalso implements GeneradorEmbedding {
  @override
  Future<List<double>> generar({required String texto}) async {
    return [1.0, 0.0];
  }
}

class RepositorioConocimientoFalso implements RepositorioConocimiento {
  @override
  Future<List<ChunkConocimiento>> obtenerChunks() async {
    return const [
      ChunkConocimiento(
        id: 'chunk-a',
        documentoId: 'doc-1',
        contenido: 'Contenido A',
        orden: 1,
      ),
      ChunkConocimiento(
        id: 'chunk-b',
        documentoId: 'doc-1',
        contenido: 'Contenido B',
        orden: 2,
      ),
      ChunkConocimiento(
        id: 'chunk-c',
        documentoId: 'doc-1',
        contenido: 'Contenido C',
        orden: 3,
      ),
    ];
  }

  @override
  Future<List<EmbeddingChunk>> obtenerEmbeddings() async {
    return const [
      EmbeddingChunk(chunkId: 'chunk-a', vector: [1.0, 0.0]),
      EmbeddingChunk(chunkId: 'chunk-b', vector: [0.0, 1.0]),
      EmbeddingChunk(chunkId: 'chunk-c', vector: [0.8, 0.2]),
    ];
  }
}

void main() {
  test('recupera los chunks con mayor similitud primero', () async {
    final service = RecuperadorVectorialService(
      generadorEmbedding: GeneradorEmbeddingFalso(),
      similitudCoseno: const SimilitudCosenoService(),
      repositorio: RepositorioConocimientoFalso(),
    );

    final resultado = await service.recuperar(
      consulta: 'suma de matrices',
      limite: 2,
    );
    expect(resultado.length, 2);
    expect(resultado[0].id, 'chunk-a');
    expect(resultado[1].id, 'chunk-c');
  });
}
