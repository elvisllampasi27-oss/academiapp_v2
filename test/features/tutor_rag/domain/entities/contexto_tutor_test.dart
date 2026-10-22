import 'package:academiapp_v2/features/adaptive_engine/domain/entities/recomendacion.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/estado_dominio.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/chunk_conocimiento.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/consulta_tutor.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/contexto_tutor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'el contexto del tutor integra estudiante dominio recomendacion y RAG',
    () {
      const consulta = ConsultaTutor(
        matriculaId: 'matricula-1',
        habilidadId: 'suma-matrices',
        pregunta: 'No entiendo como sumar matrices.',
      );

      final estadoDominio = EstadoDominio(
        matriculaId: 'matricula-1',
        habilidadId: 'suma-matrices',
        valor: 0.32,
        nivel: NivelDominio.bajo,
        modeloVersion: 'bkt-v1',
        actualizadoEn: DateTime(2026, 10, 21),
      );

      final recomendacion = Recomendacion(
        id: 'matricula-1-suma-matrices',
        matriculaId: 'matricula-1',
        habilidadId: 'suma-matrices',
        tipo: TipoRecomendacion.reforzar,
        motivo: 'La habilidad presenta un nivel de dominio bajo.',
        prioridad: 3,
        fecha: DateTime(2026, 10, 21),
      );

      const chunks = [
        ChunkConocimiento(
          id: 'chunk-1',
          documentoId: 'documento-matrices',
          contenido: 'Para sumar matrices deben tener las mismas dimensiones.',
          orden: 1,
        ),
      ];

      final contexto = ContextoTutor(
        consulta: consulta,
        estadoDominio: estadoDominio,
        recomendacion: recomendacion,
        chunks: chunks,
      );

      expect(contexto.consulta.habilidadId, 'suma-matrices');
      expect(contexto.estadoDominio.valor, 0.32);
      expect(contexto.estadoDominio.nivel, NivelDominio.bajo);
      expect(contexto.recomendacion.tipo, TipoRecomendacion.reforzar);
      expect(contexto.chunks.length, 1);
      expect(contexto.chunks.first.id, 'chunk-1');
    },
  );
}
