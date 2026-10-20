import '../entities/configuracion_inicio.dart';

class CalcularInicioAcademicoService {
  const CalcularInicioAcademicoService();

  DateTime calcular({
    required DateTime fechaMatricula,
    required DateTime fechaAperturaVersion,
    required ConfiguracionInicio configuracion,
  }) {
    var fechaInicio = DateTime(
      fechaMatricula.year,
      fechaMatricula.month,
      fechaMatricula.day,
      configuracion.horaInicio,
    );

    final ocurrioDespuesDelCorte =
        fechaMatricula.hour >= configuracion.horaCorte;

    if (ocurrioDespuesDelCorte) {
      fechaInicio = fechaInicio.add(const Duration(days: 1));
    }

    final apertura = DateTime(
      fechaAperturaVersion.year,
      fechaAperturaVersion.month,
      fechaAperturaVersion.day,
      configuracion.horaInicio,
    );

    if (fechaInicio.isBefore(apertura)) {
      fechaInicio = apertura;
    }

    while (fechaInicio.weekday == DateTime.sunday) {
      fechaInicio = fechaInicio.add(const Duration(days: 1));
    }

    return fechaInicio;
  }
}
