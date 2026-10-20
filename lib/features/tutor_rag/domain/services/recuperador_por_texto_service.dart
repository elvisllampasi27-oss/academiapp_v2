import '../entities/chunk_conocimiento.dart';
import '../repositories/recuperador_conocimiento.dart';

class RecuperadorPorTextoService implements RecuperadorConocimiento {
  const RecuperadorPorTextoService();

  @override
  Future<List<ChunkConocimiento>> recuperar({
    required String consulta,
    required List<ChunkConocimiento> chunks,
    int limite = 3,
  }) async {
    final palabras = consulta
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((palabra) => palabra.length > 2)
        .toSet();

    final resultados = chunks
        .where((chunk) {
          final contenido = chunk.contenido.toLowerCase();

          return palabras.any(contenido.contains);
        })
        .take(limite)
        .toList();

    return resultados;
  }
}
