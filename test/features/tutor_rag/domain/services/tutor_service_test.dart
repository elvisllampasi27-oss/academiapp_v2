import 'package:academiapp_v2/features/adaptive_engine/domain/entities/recomendacion.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/estado_dominio.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/chunk_conocimiento.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/consulta_tutor.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/entities/contexto_tutor.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/exceptions/conocimiento_no_encontrado_exception.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/repositories/generador_respuesta_tutor.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/services/recuperador_por_texto_service.dart';
import 'package:academiapp_v2/features/tutor_rag/domain/services/tutor_service.dart';
import 'package:flutter_test/flutter_test.dart';

class GeneradorTutorFalso implements GeneradorRespuestaTutor {
  @override
  Future<String> generar({required ContextoTutor contexto}) async {
    final conocimiento = contexto.chunks.first.contenido;

    return '${contexto.recomendacion.tipo.name}: $conocimiento';
  }
}

class GeneradorQueNoDebeLlamarse implements GeneradorRespuestaTutor {
  bool fueLlamado = false;

  @override
  Future<String> generar({required ContextoTutor contexto}) async {
    fueLlamado = true;
    return 'Esta respuesta no deberia generarse.';
  }
}

void main() {
  test('Tutor integra recomendacion y conocimiento recuperado', () async {
    final tutor = TutorService(
      recuperador: const RecuperadorPorTextoService(),
      generador: GeneradorTutorFalso(),
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
        documentoId: 'doc-1',
        contenido: 'Una matriz es un arreglo rectangular.',
        orden: 1,
      ),
      ChunkConocimiento(
        id: 'chunk-2',
        documentoId: 'doc-1',
        contenido: 'Para sumar matrices deben tener las mismas dimensiones.',
        orden: 2,
      ),
    ];

    final respuesta = await tutor.responder(
      consulta: consulta,
      estadoDominio: estado,
      recomendacion: recomendacion,
      chunksDisponibles: chunks,
    );

    expect(respuesta, contains('reforzar'));

    expect(respuesta, contains('sumar matrices'));
  });

  test(
    'Tutor no genera respuesta cuando RAG no encuentra conocimiento',
    () async {
      final generador = GeneradorQueNoDebeLlamarse();

      final tutor = TutorService(
        recuperador: const RecuperadorPorTextoService(),
        generador: generador,
      );

      const consulta = ConsultaTutor(
        matriculaId: 'matricula-1',
        habilidadId: 'derivadas',
        pregunta: 'Explicame derivadas.',
      );

      final estado = EstadoDominio(
        matriculaId: 'matricula-1',
        habilidadId: 'derivadas',
        valor: 0.30,
        nivel: NivelDominio.bajo,
        modeloVersion: 'bkt-v1',
        actualizadoEn: DateTime(2026, 10, 21),
      );

      final recomendacion = Recomendacion(
        id: 'recomendacion-1',
        matriculaId: 'matricula-1',
        habilidadId: 'derivadas',
        tipo: TipoRecomendacion.reforzar,
        motivo: 'Dominio bajo.',
        prioridad: 3,
        fecha: DateTime(2026, 10, 21),
      );

      const chunks = [
        ChunkConocimiento(
          id: 'chunk-1',
          documentoId: 'doc-matrices',
          contenido: 'Para sumar matrices deben tener las mismas dimensiones.',
          orden: 1,
        ),
      ];

      expect(
        () => tutor.responder(
          consulta: consulta,
          estadoDominio: estado,
          recomendacion: recomendacion,
          chunksDisponibles: chunks,
        ),
        throwsA(isA<ConocimientoNoEncontradoException>()),
      );

      await Future<void>.delayed(Duration.zero);

      expect(generador.fueLlamado, isFalse);
    },
  );
}
