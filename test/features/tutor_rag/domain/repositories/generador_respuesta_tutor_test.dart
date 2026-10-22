import 'package:academiapp_v2/features/adaptive_engine/domain/entities/recomendacion.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/estado_dominio.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/chunk_conocimiento.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/consulta_tutor.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/contexto_tutor.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/repositories/generador_respuesta_tutor.dart';
import 'package:flutter_test/flutter_test.dart';

class GeneradorFalso implements GeneradorRespuestaTutor {
  @override
  Future<String> generar({required ContextoTutor contexto}) async {
    return 'Explicacion para ${contexto.consulta.habilidadId}';
  }
}

void main() {
  test(
    'un generador puede producir una respuesta usando ContextoTutor',
    () async {
      const consulta = ConsultaTutor(
        matriculaId: 'matricula-1',
        habilidadId: 'suma-matrices',
        pregunta: 'No entiendo como sumar matrices.',
      );

      final estado = EstadoDominio(
        matriculaId: 'matricula-1',
        habilidadId: 'suma-matrices',
        valor: 0.32,
        nivel: NivelDominio.bajo,
        modeloVersion: 'bkt-v1',
        actualizadoEn: DateTime(2026, 10, 21),
      );

      final recomendacion = Recomendacion(
        id: 'recomendacion-1',
        matriculaId: 'matricula-1',
        habilidadId: 'suma-matrices',
        tipo: TipoRecomendacion.reforzar,
        motivo: 'Dominio bajo.',
        prioridad: 3,
        fecha: DateTime(2026, 10, 21),
      );

      const chunks = [
        ChunkConocimiento(
          id: 'chunk-1',
          documentoId: 'documento-1',
          contenido: 'Para sumar matrices deben tener las mismas dimensiones.',
          orden: 1,
        ),
      ];

      final contexto = ContextoTutor(
        consulta: consulta,
        estadoDominio: estado,
        recomendacion: recomendacion,
        chunks: chunks,
      );

      final generador = GeneradorFalso();

      final respuesta = await generador.generar(contexto: contexto);

      expect(respuesta, 'Explicacion para suma-matrices');
    },
  );
}
