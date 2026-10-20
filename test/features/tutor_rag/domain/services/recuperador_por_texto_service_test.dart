import 'package:academiapp_v2/features/tutor_rag/domain/entities/chunk_conocimiento.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/services/recuperador_por_texto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = RecuperadorPorTextoService();

  const chunks = [
    ChunkConocimiento(
      id: 'chunk-1',
      documentoId: 'doc-1',
      contenido: 'Una matriz es un arreglo rectangular de elementos.',
      orden: 1,
    ),
    ChunkConocimiento(
      id: 'chunk-2',
      documentoId: 'doc-1',
      contenido: 'Para sumar matrices deben tener el mismo orden.',
      orden: 2,
    ),
    ChunkConocimiento(
      id: 'chunk-3',
      documentoId: 'doc-1',
      contenido: 'La multiplicacion de matrices utiliza filas y columnas.',
      orden: 3,
    ),
  ];

  test('recupera un chunk relacionado con la consulta', () async {
    final resultado = await service.recuperar(
      consulta: '¿Como puedo sumar matrices?',
      chunks: chunks,
    );

    expect(resultado, isNotEmpty);
    expect(resultado.any((chunk) => chunk.id == 'chunk-2'), isTrue);
  });

  test('respeta el limite de resultados', () async {
    final resultado = await service.recuperar(
      consulta: 'matrices',
      chunks: chunks,
      limite: 2,
    );

    expect(resultado.length, 2);
  });

  test('devuelve vacio cuando no encuentra contenido relacionado', () async {
    final resultado = await service.recuperar(
      consulta: 'geometria triangulos',
      chunks: chunks,
    );

    expect(resultado, isEmpty);
  });
}
