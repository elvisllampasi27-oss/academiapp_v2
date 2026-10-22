import '../entities/chunk_conocimiento.dart';
import '../repositories/generador_embedding.dart';
import '../repositories/recuperador_conocimiento.dart';
import '../repositories/repositorio_conocimiento.dart';
import 'similitud_coseno_service.dart';

class RecuperadorVectorialService implements RecuperadorConocimiento {
  final GeneradorEmbedding generadorEmbedding;
  final SimilitudCosenoService similitudCoseno;
  final RepositorioConocimiento repositorio;
  final double similitudMinima;

  const RecuperadorVectorialService({
    required this.generadorEmbedding,
    required this.similitudCoseno,
    required this.repositorio,
    this.similitudMinima = 0.5,
  }) : assert(
         similitudMinima >= -1 && similitudMinima <= 1,
         'La similitud minima debe estar entre -1 y 1.',
       );

  @override
  Future<List<ChunkConocimiento>> recuperar({
    required String consulta,
    int limite = 3,
  }) async {
    final chunksAlmacenados = await repositorio.obtenerChunks();
    final embeddings = await repositorio.obtenerEmbeddings();

    final embeddingConsulta = await generadorEmbedding.generar(texto: consulta);

    final chunksPorId = {
      for (final chunk in chunksAlmacenados) chunk.id: chunk,
    };

    final resultados = <({ChunkConocimiento chunk, double similitud})>[];

    for (final embedding in embeddings) {
      final chunk = chunksPorId[embedding.chunkId];

      if (chunk == null) {
        continue;
      }

      final similitud = similitudCoseno.calcular(
        vectorA: embeddingConsulta,
        vectorB: embedding.vector,
      );

      if (similitud >= similitudMinima) {
        resultados.add((chunk: chunk, similitud: similitud));
      }
    }

    resultados.sort((a, b) => b.similitud.compareTo(a.similitud));

    return resultados.take(limite).map((resultado) => resultado.chunk).toList();
  }
}
