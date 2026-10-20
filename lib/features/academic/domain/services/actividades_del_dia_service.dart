import '../entities/actividad_programada.dart';
import '../entities/dia_academico.dart';

class ActividadesDelDiaService {
  const ActividadesDelDiaService();

  List<ActividadProgramada> obtener({
    required List<DiaAcademico> calendario,
    required DateTime fecha,
  }) {
    final fechaBuscada = DateTime(fecha.year, fecha.month, fecha.day);

    for (final dia in calendario) {
      if (dia.fecha == null) {
        continue;
      }

      final fechaDia = DateTime(
        dia.fecha!.year,
        dia.fecha!.month,
        dia.fecha!.day,
      );

      if (fechaDia == fechaBuscada) {
        return dia.actividades
            .where(
              (actividad) =>
                  actividad.estado == EstadoActividadProgramada.publicada,
            )
            .toList();
      }
    }

    return const [];
  }
}
