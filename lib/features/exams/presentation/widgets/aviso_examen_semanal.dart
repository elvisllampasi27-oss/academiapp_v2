import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/formato_fecha.dart';
import '../../domain/entities/simulacro.dart';
import '../../domain/repositories/servicio_examenes.dart';
import '../../../../core/presentation/animaciones.dart';

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
        // Al llegar la respuesta el aviso abre su espacio suave y entra
        // desenfocado (sin empujar de golpe lo de abajo).
        return AnimatedSize(
          duration: sinAnimaciones(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: e == null || !e.disponible
              ? const SizedBox(width: double.infinity)
              : EntradaDifuminada(child: _aviso(e)),
        );
      },
    );
  }

  Widget _aviso(EstadoExamenSemanal e) {
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
                const Icon(Icons.event_note_outlined, color: ColoresApp.ambar),
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
  }
}
