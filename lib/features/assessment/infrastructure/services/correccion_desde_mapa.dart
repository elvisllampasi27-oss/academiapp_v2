import '../../domain/entities/correccion_intento.dart';
import '../../domain/entities/resultado_evaluacion.dart';

/// Convierte la respuesta de la Cloud Function en entidades del dominio.
/// Función pura: se prueba sin Firebase.
CorreccionIntento correccionDesdeMapa(Map<Object?, Object?> datos) {
  final detalle = (datos['detalle'] as List? ?? const [])
      .cast<Map<Object?, Object?>>()
      .map(
        (d) => CorreccionPregunta(
          preguntaId: d['preguntaId'] as String,
          opcionElegidaId: d['opcionElegidaId'] as String?,
          opcionCorrectaId: d['opcionCorrectaId'] as String,
          esCorrecta: d['esCorrecta'] == true,
          explicacion: d['explicacion'] as String?,
        ),
      )
      .toList();

  return CorreccionIntento(
    intentoId: datos['intentoId'] as String,
    resultado: ResultadoEvaluacion(
      totalPreguntas: (datos['total'] as num).toInt(),
      respuestasCorrectas: (datos['correctas'] as num).toInt(),
      respuestasIncorrectas: (datos['incorrectas'] as num).toInt(),
      puntaje: (datos['puntaje'] as num).toDouble(),
    ),
    detalle: detalle,
  );
}
