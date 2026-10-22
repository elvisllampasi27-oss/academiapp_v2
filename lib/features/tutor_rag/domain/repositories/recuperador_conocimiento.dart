import '../entities/chunk_conocimiento.dart';

abstract class RecuperadorConocimiento {
  Future<List<ChunkConocimiento>> recuperar({
    required String consulta,
    int limite = 3,
  });
}
