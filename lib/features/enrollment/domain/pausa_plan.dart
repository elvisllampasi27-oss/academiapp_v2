/// Pausa del plan: cuando se acaba la prueba gratis o el Premium, el plan se
/// queda en la semana en que iba. Al pagar se retoma desde el lunes de esa
/// semana: si ese día es lunes, el mismo día; si no, el lunes que viene. Se
/// corre el inicio del plan un número exacto de semanas, así los temas de
/// cada día y el examen del sábado no cambian de día de la semana.
///
/// Igual que functions/src/comun/pausa.js (el servidor la aplica al cobrar
/// con Google Play o Culqi; el panel, al aprobar un pago o dar Premium).
library;

DateTime _dia(DateTime f) => DateTime.utc(f.year, f.month, f.day);

/// Semana del plan (1, 2, 3…) en [dia]. La semana va de lunes a domingo; si
/// empezó un sábado o domingo, su semana 1 es la siguiente. 0 si todavía no
/// empieza. Igual que semanaAcademica() del servidor.
int semanaDelPlan(DateTime inicio, DateTime dia) {
  final i = _dia(inicio);
  var lunes = i.subtract(Duration(days: i.weekday - DateTime.monday));
  if (i.weekday >= DateTime.saturday) {
    lunes = lunes.add(const Duration(days: 7));
  }
  final d = _dia(dia);
  if (d.isBefore(i) || d.isBefore(lunes)) return 0;
  return d.difference(lunes).inDays ~/ 7 + 1;
}

/// El plan está en pausa: se acabó la prueba o el Premium.
class PausaPlan {
  /// Primer día sin Premium.
  final DateTime desde;

  /// Semana del plan en la que se quedó.
  final int semana;

  /// Lo que se acabó fue la prueba gratis (no un Premium pagado).
  final bool eraPrueba;

  const PausaPlan({
    required this.desde,
    required this.semana,
    required this.eraPrueba,
  });
}

/// null si el plan no está en pausa: tiene Premium o nunca tuvo (lo
/// matriculó el panel sin prueba).
PausaPlan? pausaDelPlan({
  required DateTime inicio,
  required DateTime? premiumHasta,
  DateTime? pruebaHasta,
  required DateTime ahora,
}) {
  final hasta = premiumHasta;
  if (hasta == null || hasta.isAfter(ahora)) return null;
  final desde = _dia(hasta).isAfter(_dia(inicio)) ? hasta : inicio;
  final semana = semanaDelPlan(inicio, desde);
  return PausaPlan(
    desde: DateTime(desde.year, desde.month, desde.day),
    semana: semana < 1 ? 1 : semana,
    eraPrueba: pruebaHasta != null && !hasta.isAfter(pruebaHasta),
  );
}

/// Cómo se retoma un plan en pausa al pagar en [ahora].
class RetomaPlan {
  final int semana;

  /// Días que se corre el inicio del plan (siempre semanas completas).
  final int desplazamientoDias;

  /// El lunes en que retoma.
  final DateTime retomaEl;

  const RetomaPlan({
    required this.semana,
    required this.desplazamientoDias,
    required this.retomaEl,
  });
}

/// null si no hay nada que retomar (no estaba en pausa, o se pausó hoy y
/// hoy es lunes).
RetomaPlan? retomaDelPlan({
  required DateTime inicio,
  required DateTime? premiumHasta,
  required DateTime ahora,
}) {
  final pausa = pausaDelPlan(
    inicio: inicio,
    premiumHasta: premiumHasta,
    ahora: ahora,
  );
  if (pausa == null) return null;
  final lunesPausa = _dia(pausa.desde)
      .subtract(Duration(days: pausa.desde.weekday - DateTime.monday));
  final hoy = _dia(ahora);
  final retoma = hoy.weekday == DateTime.monday
      ? hoy
      : hoy.add(Duration(days: 8 - hoy.weekday));
  final desplazamiento = retoma.difference(lunesPausa).inDays;
  if (desplazamiento <= 0) return null;
  return RetomaPlan(
    semana: pausa.semana,
    desplazamientoDias: desplazamiento,
    retomaEl: DateTime(retoma.year, retoma.month, retoma.day),
  );
}

/// Corre [inicio] los días de [retoma] (mismo día de la semana y hora).
DateTime inicioRetomado(DateTime inicio, RetomaPlan retoma) => DateTime(
  inicio.year,
  inicio.month,
  inicio.day + retoma.desplazamientoDias,
  inicio.hour,
  inicio.minute,
);
