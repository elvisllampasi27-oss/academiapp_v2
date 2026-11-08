import 'package:flutter/material.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/formato_fecha.dart';
import '../domain/relevancia_seminario.dart';
import '../domain/seminario.dart';

/// Tarjeta compacta de un seminario. Si le ayuda al alumno con un tema por
/// reforzar ([ayuda]), lleva un tono naranja suave y dice con qué tema; si
/// no tiene relación, va con el color normal de las tarjetas.
class TarjetaSeminario extends StatelessWidget {
  final Seminario seminario;
  final EstadoSeminario estado;
  final TemaPorReforzar? ayuda;
  final VoidCallback alAbrir;

  const TarjetaSeminario({
    super.key,
    required this.seminario,
    required this.estado,
    required this.alAbrir,
    this.ayuda,
  });

  @override
  Widget build(BuildContext context) {
    final destacado = ayuda != null;
    final (icono, cuando) = switch (estado) {
      EstadoSeminario.enVivo => (Icons.sensors, 'En vivo ahora'),
      EstadoSeminario.proximo => (
        Icons.event_outlined,
        '${fechaCorta(seminario.fecha)} · ${horaCorta(seminario.fecha)}',
      ),
      EstadoSeminario.grabado => (
        Icons.play_circle_outline,
        'Grabado · ${seminario.duracionMinutos} min',
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: destacado ? const Color(0x14FF8A5B) : ColoresApp.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: destacado ? const Color(0x59FF8A5B) : ColoresApp.borde,
          ),
        ),
        child: InkWell(
          onTap: alAbrir,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Icon(
                  icono,
                  size: 22,
                  color: estado == EstadoSeminario.enVivo || destacado
                      ? ColoresApp.naranja
                      : ColoresApp.apagado,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seminario.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [?seminario.curso, cuando].join(' · '),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: ColoresApp.apagado,
                        ),
                      ),
                      if (ayuda case final ayuda?) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Te ayuda con ${ayuda.tema} · dominio '
                          '${(ayuda.dominio * 100).round()} %',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: ColoresApp.naranja,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: ColoresApp.tenue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
