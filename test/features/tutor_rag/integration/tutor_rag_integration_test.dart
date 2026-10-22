import 'package:academiapp_v2/features/adaptive_engine/domain/entities/recomendacion.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/estado_dominio.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/chunk_conocimiento.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/consulta_tutor.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/contexto_tutor.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/embedding_chunk.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/exceptions/conocimiento_no_encontrado_exception.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/repositories/generador_embedding.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/repositories/generador_respuesta_tutor.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/services/recuperador_vectorial_service.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/services/similitud_coseno_service.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/services/tutor_service.dart';
import 'package:academiapp_v2/features/tutor_rag/infrastructure/repositories/repositorio_conocimiento_en_memoria.dart';
import 'package:flutter_test/flutter_test.dart';

class GeneradorEmbeddingIntegracion implements GeneradorEmbedding {
  @override
  Future<List<double>> generar({required String texto}) async {
    return [1.0, 0.0];
  }
}

class GeneradorEmbeddingNoRelacionado implements GeneradorEmbedding {
  @override
  Future<List<double>> generar({required String texto}) async {
    return [-1.0, 0.0];
  }
}

class GeneradorRespuestaIntegracion implements GeneradorRespuestaTutor {
  @override
  Future<String> generar({required ContextoTutor contexto}) async {
    final conocimiento = contexto.chunks.first.contenido;
    final tipo = contexto.recomendacion.tipo.name;

    return '$tipo: $conocimiento';
  }
}

class GeneradorRespuestaControlado implements GeneradorRespuestaTutor {
  bool fueLlamado = false;

  @override
  Future<String> generar({required ContextoTutor contexto}) async {
    fueLlamado = true;
    return 'Respuesta que no deberia generarse.';
  }
}

void main() {
  test(
    'Tutor usa RAG vectorial y conocimiento relevante para responder',
    () async {
      const repositorio = RepositorioConocimientoEnMemoria(
        chunks: [
          ChunkConocimiento(
            id: 'chunk-matrices',
            documentoId: 'doc-matrices',
            contenido:
                'Para sumar matrices deben tener las mismas dimensiones.',
            orden: 1,
          ),
          ChunkConocimiento(
            id: 'chunk-derivadas',
            documentoId: 'doc-derivadas',
            contenido: 'La derivada representa una razon de cambio.',
            orden: 1,
          ),
        ],
        embeddings: [
          EmbeddingChunk(chunkId: 'chunk-matrices', vector: [1.0, 0.0]),
          EmbeddingChunk(chunkId: 'chunk-derivadas', vector: [0.0, 1.0]),
        ],
      );

      final recuperador = RecuperadorVectorialService(
        generadorEmbedding: GeneradorEmbeddingIntegracion(),
        similitudCoseno: const SimilitudCosenoService(),
        repositorio: repositorio,
      );

      final tutor = TutorService(
        recuperador: recuperador,
        generador: GeneradorRespuestaIntegracion(),
      );

      const consulta = ConsultaTutor(
        matriculaId: 'matricula-1',
        habilidadId: 'suma-matrices',
        pregunta: '¿Como puedo sumar matrices?',
      );

      final estado = EstadoDominio(
        matriculaId: 'matricula-1',
        habilidadId: 'suma-matrices',
        valor: 0.32,
        nivel: NivelDominio.bajo,
        modeloVersion: 'bkt-v1',
        actualizadoEn: DateTime(2026, 10, 22),
      );

      final recomendacion = Recomendacion(
        id: 'recomendacion-1',
        matriculaId: 'matricula-1',
        habilidadId: 'suma-matrices',
        tipo: TipoRecomendacion.reforzar,
        motivo: 'El estudiante presenta dominio bajo.',
        prioridad: 3,
        fecha: DateTime(2026, 10, 22),
      );

      final respuesta = await tutor.responder(
        consulta: consulta,
        estadoDominio: estado,
        recomendacion: recomendacion,
        limiteChunks: 1,
      );

      expect(respuesta, contains('reforzar'));
      expect(respuesta, contains('sumar matrices'));
      expect(respuesta, isNot(contains('derivada')));
    },
  );

  test(
    'Tutor no genera respuesta si RAG no encuentra conocimiento relevante',
    () async {
      const repositorio = RepositorioConocimientoEnMemoria(
        chunks: [
          ChunkConocimiento(
            id: 'chunk-matrices',
            documentoId: 'doc-matrices',
            contenido:
                'Para sumar matrices deben tener las mismas dimensiones.',
            orden: 1,
          ),
        ],
        embeddings: [
          EmbeddingChunk(chunkId: 'chunk-matrices', vector: [1.0, 0.0]),
        ],
      );

      final recuperador = RecuperadorVectorialService(
        generadorEmbedding: GeneradorEmbeddingNoRelacionado(),
        similitudCoseno: const SimilitudCosenoService(),
        repositorio: repositorio,
        similitudMinima: 0.5,
      );

      final generador = GeneradorRespuestaControlado();

      final tutor = TutorService(
        recuperador: recuperador,
        generador: generador,
      );

      const consulta = ConsultaTutor(
        matriculaId: 'matricula-1',
        habilidadId: 'mitosis',
        pregunta: 'Explicame la mitosis.',
      );

      final estado = EstadoDominio(
        matriculaId: 'matricula-1',
        habilidadId: 'mitosis',
        valor: 0.25,
        nivel: NivelDominio.bajo,
        modeloVersion: 'bkt-v1',
        actualizadoEn: DateTime(2026, 10, 22),
      );

      final recomendacion = Recomendacion(
        id: 'recomendacion-mitosis',
        matriculaId: 'matricula-1',
        habilidadId: 'mitosis',
        tipo: TipoRecomendacion.reforzar,
        motivo: 'El estudiante presenta dominio bajo.',
        prioridad: 3,
        fecha: DateTime(2026, 10, 22),
      );

      await expectLater(
        tutor.responder(
          consulta: consulta,
          estadoDominio: estado,
          recomendacion: recomendacion,
        ),
        throwsA(isA<ConocimientoNoEncontradoException>()),
      );

      expect(generador.fueLlamado, isFalse);
    },
  );
}
