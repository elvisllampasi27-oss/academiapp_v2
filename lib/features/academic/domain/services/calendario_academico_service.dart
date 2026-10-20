import '../entities/actividad_programada.dart';
import '../entities/dia_academico.dart';
import '../entities/tema.dart';

class CalendarioAcademicoService {
  const CalendarioAcademicoService();

  List<DiaAcademico> generar({
    required List<Tema> secuencia,
    required DateTime fechaInicio,
  }) {
    final dias = <DiaAcademico>[];

    var posicion = 0;
    var numeroDia = 1;

    var fechaActual = DateTime(
      fechaInicio.year,
      fechaInicio.month,
      fechaInicio.day,
    );

    while (posicion < secuencia.length) {
      if (fechaActual.weekday == DateTime.sunday) {
        fechaActual = fechaActual.add(const Duration(days: 1));
        continue;
      }

      final cantidadTemas = fechaActual.weekday == DateTime.saturday ? 2 : 3;

      final fin = (posicion + cantidadTemas < secuencia.length)
          ? posicion + cantidadTemas
          : secuencia.length;

      final temasDelDia = secuencia.sublist(posicion, fin);

      final actividades = <ActividadProgramada>[];

      for (var i = 0; i < temasDelDia.length; i++) {
        actividades.add(
          ActividadProgramada(
            id: 'dia-$numeroDia-actividad-${i + 1}',
            diaId: 'dia-$numeroDia',
            temaId: temasDelDia[i].id,
            orden: i + 1,
          ),
        );
      }

      dias.add(
        DiaAcademico(
          numero: numeroDia,
          fecha: fechaActual,
          actividades: actividades,
        ),
      );

      posicion = fin;
      numeroDia++;
      fechaActual = fechaActual.add(const Duration(days: 1));
    }

    return dias;
  }
}
