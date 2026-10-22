import '../../../adaptive_engine/domain/entities/recomendacion.dart';
import '../../../student_model/domain/entities/estado_dominio.dart';
import '../entities/consulta_tutor.dart';
import '../entities/contexto_tutor.dart';
import '../exceptions/conocimiento_no_encontrado_exception.dart';
import '../repositories/generador_respuesta_tutor.dart';
import '../repositories/recuperador_conocimiento.dart';

class TutorService {
  final RecuperadorConocimiento recuperador;
  final GeneradorRespuestaTutor generador;

  const TutorService({required this.recuperador, required this.generador});

  Future<String> responder({
    required ConsultaTutor consulta,
    required EstadoDominio estadoDominio,
    required Recomendacion recomendacion,

    int limiteChunks = 3,
  }) async {
    final chunksRecuperados = await recuperador.recuperar(
      consulta: consulta.pregunta,
      limite: limiteChunks,
    );

    if (chunksRecuperados.isEmpty) {
      throw const ConocimientoNoEncontradoException();
    }

    final contexto = ContextoTutor(
      consulta: consulta,
      estadoDominio: estadoDominio,
      recomendacion: recomendacion,
      chunks: chunksRecuperados,
    );

    return generador.generar(contexto: contexto);
  }
}
