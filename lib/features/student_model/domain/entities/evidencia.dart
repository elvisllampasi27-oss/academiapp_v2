enum ResultadoEvidencia { correcta, incorrecta }

enum OrigenEvidencia { practica, evaluacion, simulacro }

enum DificultadEvidencia { basica, intermedia, avanzada }

class Evidencia {
  final String id;
  final String matriculaId;
  final String respuestaId;
  final String habilidadId;
  final OrigenEvidencia origen;
  final ResultadoEvidencia resultado;
  final DificultadEvidencia dificultad;
  final int numeroIntento;
  final bool ayudaUtilizada;
  final DateTime fecha;

  const Evidencia({
    required this.id,
    required this.matriculaId,
    required this.respuestaId,
    required this.habilidadId,
    required this.origen,
    required this.resultado,
    required this.dificultad,
    required this.numeroIntento,
    required this.ayudaUtilizada,
    required this.fecha,
  });
}
