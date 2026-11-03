import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/formato_fecha.dart';
import '../../domain/entities/simulacro.dart';
import '../../domain/repositories/servicio_examenes.dart';

/// Aviso en el Inicio cuando el examen semanal está abierto y aún no lo
/// dio. Si no hay examen (o no se pudo consultar), no ocupa espacio.
class AvisoExamenSemanal extends StatefulWidget {
  final ServicioExamenes servicio;
  final VoidCallback onAbrir;

  const AvisoExamenSemanal({
    super.key,
    required this.servicio,
    required this.onAbrir,
  });

  @override
  State<AvisoExamenSemanal> createState() => _AvisoExamenSemanalState();
}

class _AvisoExamenSemanalState extends State<AvisoExamenSemanal> {
  late final Future<EstadoExamenSemanal> _estado = widget.servicio
      .estadoSemanal();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EstadoExamenSemanal>(
      future: _estado,
      builder: (context, s) {
        final e = s.data;
        if (e == null || !e.disponible) return const SizedBox.shrink();
        final hasta = e.cierra == null
            ? ''
            : ' · hasta el ${fechaCorta(e.cierra!.subtract(const Duration(minutes: 1))).toLowerCase()}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Material(
            color: ColoresApp.ambar.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: ColoresApp.ambar.withValues(alpha: 0.4)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onAbrir,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_note_outlined,
                      color: ColoresApp.ambar,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.intento == EstadoIntento.enCurso
                                ? 'Tienes tu examen de la semana ${e.semana} en curso'
                                : 'Tu examen de la semana ${e.semana} está listo',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Un solo intento$hasta',
                            style: const TextStyle(color: ColoresApp.apagado),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: ColoresApp.ambar),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
