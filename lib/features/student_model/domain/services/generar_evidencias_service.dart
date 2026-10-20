import '../../../assessment/domain/entities/respuesta.dart';
import '../entities/evidencia.dart';
import '../entities/pregunta_habilidad.dart';

class GenerarEvidenciasService {
  List<Evidencia> generar({
    required Respuesta respuesta,
    required List<PreguntaHabilidad> relaciones,
    required String matriculaId,
    required OrigenEvidencia origen,
    required DificultadEvidencia dificultad,
    required int numeroIntento,
    required bool ayudaUtilizada,
    required DateTime fecha,
  }) {
    final relacionesDeLaPregunta = relaciones
        .where((relacion) => relacion.preguntaId == respuesta.preguntaId)
        .toList();

    return relacionesDeLaPregunta.map((relacion) {
      return Evidencia(
        id: '${respuesta.id}-${relacion.habilidadId}',
        matriculaId: matriculaId,
        respuestaId: respuesta.id,
        habilidadId: relacion.habilidadId,
        origen: origen,
        resultado: respuesta.esCorrecta
            ? ResultadoEvidencia.correcta
            : ResultadoEvidencia.incorrecta,
        dificultad: dificultad,
        numeroIntento: numeroIntento,
        ayudaUtilizada: ayudaUtilizada,
        fecha: fecha,
      );
    }).toList();
  }
}
