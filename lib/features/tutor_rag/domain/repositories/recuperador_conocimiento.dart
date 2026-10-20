import '../entities/chunk_conocimiento.dart';

abstract class RecuperadorConocimiento {
  Future<List<ChunkConocimiento>> recuperar({
    required String consulta,
    required List<ChunkConocimiento> chunks,
    int limite = 3,
  });
}
