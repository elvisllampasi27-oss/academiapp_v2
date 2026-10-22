import 'package:academiapp_v2/features/tutor_rag/domain/repositories/generador_embedding.dart';
import 'package:flutter_test/flutter_test.dart';

class GeneradorEmbeddingFalso implements GeneradorEmbedding {
  @override
  Future<List<double>> generar({required String texto}) async {
    if (texto == 'suma de matrices') {
      return [0.9, 0.1, 0.8];
    }

    return [0.1, 0.9, 0.2];
  }
}

void main() {
  test('un generador convierte texto en un vector numerico', () async {
    final generador = GeneradorEmbeddingFalso();

    final embedding = await generador.generar(texto: 'suma de matrices');

    expect(embedding, [0.9, 0.1, 0.8]);
    expect(embedding.length, 3);
  });
}
