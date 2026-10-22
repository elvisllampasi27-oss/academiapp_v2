import '../entities/chunk_conocimiento.dart';
import '../repositories/recuperador_conocimiento.dart';
import '../repositories/repositorio_conocimiento.dart';

class RecuperadorPorTextoService implements RecuperadorConocimiento {
  final RepositorioConocimiento repositorio;

  const RecuperadorPorTextoService({required this.repositorio});

  @override
  Future<List<ChunkConocimiento>> recuperar({
    required String consulta,
    int limite = 3,
  }) async {
    final chunks = await repositorio.obtenerChunks();

    final palabras = consulta
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((palabra) => palabra.length > 2)
        .toSet();

    return chunks
        .where((chunk) {
          final contenido = chunk.contenido.toLowerCase();

          return palabras.any(contenido.contains);
        })
        .take(limite)
        .toList();
  }
}
