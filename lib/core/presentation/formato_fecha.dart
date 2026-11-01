const _dias = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'set',
  'oct',
  'nov',
  'dic',
];

/// "Sábado 31 oct". Sin paquetes extra: solo lo que la app necesita.
String fechaCorta(DateTime fecha) =>
    '${_dias[fecha.weekday - 1]} ${fecha.day} ${_meses[fecha.month - 1]}';

/// "7:00 p. m." (como se escribe en Perú).
String horaCorta(DateTime fecha) {
  final hora12 = fecha.hour % 12 == 0 ? 12 : fecha.hour % 12;
  final minutos = fecha.minute.toString().padLeft(2, '0');
  return '$hora12:$minutos ${fecha.hour < 12 ? 'a. m.' : 'p. m.'}';
}
