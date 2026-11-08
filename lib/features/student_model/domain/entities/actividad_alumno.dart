/// La actividad del alumno durante su matrícula, para el mapa de cuadritos:
/// cuántas preguntas respondió en cada día y en cada franja de 3 horas.
class ActividadAlumno {
  /// Franjas del día: 8 de 3 horas (0–3 h, 3–6 h, … 21–24 h).
  static const franjas = 8;
  static const horasPorFranja = 24 ~/ franjas;

  /// Si la matrícula no tiene fecha de fin, se muestran estos días.
  static const diasSinFin = 120;

  /// Primer y último día de la matrícula (sin hora).
  final DateTime inicio;
  final DateTime fin;
  final DateTime hoy;
  final Map<(int, int), int> _conteo;

  ActividadAlumno._(this.inicio, this.fin, this.hoy, this._conteo);

  factory ActividadAlumno.desde({
    required List<DateTime> fechas,
    required DateTime inicio,
    required DateTime hoy,
    DateTime? fin,
  }) {
    final primero = _dia(inicio);
    var ultimo = fin == null
        ? primero.add(const Duration(days: diasSinFin - 1))
        : _dia(fin);
    if (ultimo.isBefore(primero)) ultimo = primero;

    final conteo = <(int, int), int>{};
    for (final fecha in fechas) {
      final dia = _diasEntre(primero, _dia(fecha));
      if (dia < 0 || dia > _diasEntre(primero, ultimo)) continue;
      final clave = (dia, fecha.hour ~/ horasPorFranja);
      conteo[clave] = (conteo[clave] ?? 0) + 1;
    }
    return ActividadAlumno._(primero, ultimo, _dia(hoy), conteo);
  }

  /// Días de la matrícula (columnas del mapa).
  int get dias => _diasEntre(inicio, fin) + 1;

  /// Columna de hoy (puede quedar fuera si la matrícula aún no empieza o
  /// ya terminó).
  int get indiceHoy => _diasEntre(inicio, hoy);

  DateTime diaEn(int indice) =>
      DateTime(inicio.year, inicio.month, inicio.day + indice);

  /// Preguntas respondidas ese día en esa franja.
  int en(int dia, int franja) => _conteo[(dia, franja)] ?? 0;

  int totalDelDia(int dia) {
    var total = 0;
    for (var f = 0; f < franjas; f++) {
      total += en(dia, f);
    }
    return total;
  }

  int get diasActivos => {for (final (dia, _) in _conteo.keys) dia}.length;

  /// Días seguidos con actividad hasta hoy (si hoy aún no practicó, cuenta
  /// desde ayer, para no "romper" la racha a primera hora).
  int get racha {
    var dia = indiceHoy.clamp(-1, dias - 1);
    if (dia >= 0 && totalDelDia(dia) == 0) dia--;
    var seguidos = 0;
    while (dia >= 0 && totalDelDia(dia) > 0) {
      seguidos++;
      dia--;
    }
    return seguidos;
  }

  /// La franja en la que más practica, o `null` si aún no hay actividad.
  int? get franjaFuerte {
    final porFranja = List.filled(franjas, 0);
    _conteo.forEach((clave, n) => porFranja[clave.$2] += n);
    var mejor = 0;
    for (var f = 1; f < franjas; f++) {
      if (porFranja[f] > porFranja[mejor]) mejor = f;
    }
    return porFranja[mejor] == 0 ? null : mejor;
  }

  /// Días que le quedan de matrícula (0 si ya terminó).
  int get diasRestantes => _diasEntre(hoy, fin).clamp(0, dias);

  /// Intensidad del cuadrito: 0 sin actividad; 1 a 4 de menos a más.
  static int nivel(int preguntas) => switch (preguntas) {
    0 => 0,
    1 => 1,
    <= 3 => 2,
    <= 6 => 3,
    _ => 4,
  };

  static DateTime _dia(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  /// Días entre dos fechas sin hora (en UTC, para que un cambio de horario
  /// no reste o sume una hora y desplace el día).
  static int _diasEntre(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}
