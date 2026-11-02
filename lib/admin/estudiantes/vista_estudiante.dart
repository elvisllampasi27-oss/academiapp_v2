import 'package:flutter/material.dart';

import '../tema_panel.dart';
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

/// Estado en las tablas: punto de color y texto en una línea.
class PuntoSituacion extends StatelessWidget {
  final SituacionEstudiante situacion;

  const PuntoSituacion(this.situacion, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final (texto, color) = switch (situacion) {
      SituacionEstudiante.activo => ('Activa', p.secundario),
      SituacionEstudiante.programado => ('Programada', p.acento),
      SituacionEstudiante.suspendido => ('Suspendida', p.alerta),
      SituacionEstudiante.finalizado => ('Finalizada', p.tenue),
      SituacionEstudiante.sinMatricula => ('Sin matrícula', p.tenue),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
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
