import 'examen.dart';

/// Examen tipo admisión en curso.
class Simulacro {
  final String id;
  final int duracionSegundos;
  final DateTime vence;
  final List<PreguntaExamen> preguntas;

  const Simulacro({
    required this.id,
    required this.duracionSegundos,
    required this.vence,
    required this.preguntas,
  });
}

class ResultadoSeccion {
  final String nombre;
  final int correctas;
  final int total;

  const ResultadoSeccion({
    required this.nombre,
    required this.correctas,
    required this.total,
  });
}

class DetalleRespuesta {
  final String preguntaId;
  final String? opcionElegidaId;
  final String opcionCorrectaId;
  final bool esCorrecta;
  final String? solucion;
  final String? imagenSolucion;

  const DetalleRespuesta({
    required this.preguntaId,
    required this.opcionElegidaId,
    required this.opcionCorrectaId,
    required this.esCorrecta,
    this.solucion,
    this.imagenSolucion,
  });
}

class ResultadoSimulacro {
  final int correctas;
  final int total;
  final int puntaje;
  final int tiempoUsadoSegundos;
  final List<ResultadoSeccion> porSeccion;
  final List<DetalleRespuesta> detalle;

  const ResultadoSimulacro({
    required this.correctas,
    required this.total,
    required this.puntaje,
    required this.tiempoUsadoSegundos,
    required this.porSeccion,
    required this.detalle,
  });
}

/// El examen tipo admisión se da sábados y domingos (como el real).
bool esDiaDeSimulacro(DateTime hoy) =>
    hoy.weekday == DateTime.saturday || hoy.weekday == DateTime.sunday;
