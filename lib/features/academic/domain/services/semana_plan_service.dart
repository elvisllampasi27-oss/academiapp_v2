import '../../../enrollment/domain/pausa_plan.dart';
import '../entities/dia_academico.dart';
import '../entities/semana_plan.dart';

DateTime _soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

/// La semana de [hoy] en el [calendario] del plan, con sus temas
/// publicados. null si su plan todavía no empieza.
SemanaPlan? semanaDelCalendario({
  required List<DiaAcademico> calendario,
  required DateTime fechaInicio,
  required DateTime hoy,
  required Set<String> publicados,
}) {
  final numero = semanaDelPlan(fechaInicio, hoy);
  if (numero < 1) return null;
  final dia = _soloFecha(hoy);
  final lunes = DateTime(dia.year, dia.month, dia.day - (dia.weekday - 1));
  final domingo = DateTime(lunes.year, lunes.month, lunes.day + 6);
  return SemanaPlan(
    numero: numero,
    temaIds: [
      for (final d in calendario)
        if (d.fecha case final fecha?
            when !_soloFecha(fecha).isBefore(lunes) &&
                !_soloFecha(fecha).isAfter(domingo))
          for (final a in d.actividades)
            if (publicados.contains(a.temaId)) a.temaId,
    ],
    sabado: DateTime(lunes.year, lunes.month, lunes.day + 5),
  );
}
