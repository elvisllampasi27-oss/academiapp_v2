import 'resultado_evaluacion.dart';

class CorreccionPregunta {
  final String preguntaId;
  final String? opcionElegidaId;
  final String opcionCorrectaId;
  final bool esCorrecta;
  final String? explicacion;

  const CorreccionPregunta({
    required this.preguntaId,
    required this.opcionElegidaId,
    required this.opcionCorrectaId,
    required this.esCorrecta,
    this.explicacion,
  });
}

/// Lo que devuelve el servidor tras corregir un intento.
class CorreccionIntento {
  final String intentoId;
  final ResultadoEvaluacion resultado;
  final List<CorreccionPregunta> detalle;

  const CorreccionIntento({
    required this.intentoId,
    required this.resultado,
    required this.detalle,
  });
}
