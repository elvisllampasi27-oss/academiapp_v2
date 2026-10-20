import 'actividad_programada.dart';

class DiaAcademico {
  final int numero;
  final String? planId;
  final DateTime? fecha;
  final List<ActividadProgramada> actividades;

  const DiaAcademico({
    required this.numero,
    required this.actividades,
    this.planId,
    this.fecha,
  });
}
