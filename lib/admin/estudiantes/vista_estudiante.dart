import 'package:flutter/material.dart';

import '../widgets_panel.dart';
import 'modelo_estudiantes.dart';

/// Cómo se muestra la situación de un estudiante en todo el panel.
Insignia insigniaSituacion(SituacionEstudiante s) => switch (s) {
  SituacionEstudiante.activo => const Insignia(
    'Activa',
    tono: TonoInsignia.secundario,
  ),
  SituacionEstudiante.programado => const Insignia(
    'Programada',
    tono: TonoInsignia.acento,
  ),
  SituacionEstudiante.suspendido => const Insignia(
    'Suspendida',
    tono: TonoInsignia.alerta,
  ),
  SituacionEstudiante.finalizado => const Insignia('Finalizada'),
  SituacionEstudiante.sinMatricula => const Insignia('Sin matrícula'),
};

/// "23 oct · día 9", "2 nov · inicia mañana" o "—".
String textoInicio(EstudianteAdmin e, DateTime hoy) {
  final m = e.matricula;
  if (m == null) return '—';
  final inicio = m.fechaInicioAcademico;
  final dia = diaAcademico(inicio, hoy);
  if (dia > 0) return '${fechaBreve(inicio)} · día $dia';
  final hoySolo = DateTime(hoy.year, hoy.month, hoy.day);
  final faltan = DateTime(
    inicio.year,
    inicio.month,
    inicio.day,
  ).difference(hoySolo).inDays;
  return '${fechaBreve(inicio)} · ${faltan == 1 ? 'inicia mañana' : 'en $faltan días'}';
}

/// Elige una fecha de inicio (los domingos no son día académico).
Future<DateTime?> elegirInicio(
  BuildContext context, {
  required DateTime inicial,
  required DateTime desde,
}) {
  var dia = DateTime(inicial.year, inicial.month, inicial.day);
  if (dia.weekday == DateTime.sunday) {
    dia = DateTime(dia.year, dia.month, dia.day + 1);
  }
  var primera = DateTime(desde.year, desde.month, desde.day);
  if (dia.isBefore(primera)) primera = dia;
  return showDatePicker(
    context: context,
    initialDate: dia,
    firstDate: primera,
    lastDate: DateTime(desde.year + 2),
    selectableDayPredicate: (d) => d.weekday != DateTime.sunday,
    helpText: 'Día 1 del estudiante',
    cancelText: 'Cancelar',
    confirmText: 'Elegir',
  );
}
