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
