import 'examen.dart';

/// Examen semanal en curso.
class Simulacro {
  final String id;

  /// "Semana 3 · Ciclo 2026-II".
  final String titulo;
  final int duracionSegundos;
  final DateTime vence;
  final List<PreguntaExamen> preguntas;

  const Simulacro({
    required this.id,
    required this.duracionSegundos,
    required this.vence,
    required this.preguntas,
    this.titulo = 'Examen semanal',
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

/// Un puesto en el ranking del examen semanal.
class PuestoRanking {
  final int puesto;
  final String nombre;
  final int puntaje;
  final int correctas;
  final int total;
  final int tiempoUsadoSegundos;
  final bool soyYo;

  const PuestoRanking({
    required this.puesto,
    required this.nombre,
    required this.puntaje,
    required this.correctas,
    required this.total,
    required this.tiempoUsadoSegundos,
    this.soyYo = false,
  });
}

/// Los 10 primeros del examen semanal y el puesto del estudiante.
class RankingSemanal {
  final String titulo;
  final int participantes;
  final List<PuestoRanking> top;
  final PuestoRanking? yo;

  const RankingSemanal({
    required this.titulo,
    required this.participantes,
    required this.top,
    this.yo,
  });

  /// Si el estudiante no entró al top, se muestra aparte.
  bool get yoFueraDelTop => yo != null && !top.any((p) => p.soyYo);
}

enum EstadoIntento { pendiente, enCurso, completado }

/// Qué examen semanal le toca ahora al estudiante. El de la semana N se
/// abre el sábado y queda abierto hasta el sábado siguiente.
class EstadoExamenSemanal {
  /// 0 = todavía no le toca ninguno.
  final int semana;
  final String titulo;
  final bool publicado;
  final int totalPreguntas;
  final EstadoIntento intento;
  final int? puntaje;
  final DateTime? cierra;
  final bool requierePremium;

  const EstadoExamenSemanal({
    required this.semana,
    this.titulo = '',
    this.publicado = false,
    this.totalPreguntas = 0,
    this.intento = EstadoIntento.pendiente,
    this.puntaje,
    this.cierra,
    this.requierePremium = false,
  });

  /// Lo puede dar (o continuar) ahora mismo.
  bool get disponible =>
      semana > 0 &&
      publicado &&
      !requierePremium &&
      intento != EstadoIntento.completado;
}
