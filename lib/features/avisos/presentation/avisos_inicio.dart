import 'package:flutter/material.dart';

import '../../../core/presentation/colores_app.dart';
import '../domain/aviso.dart';
import '../../../core/presentation/animaciones.dart';

/// Avisos del equipo arriba del Inicio. Si no hay (o no cargan), no ocupa
/// espacio. La X lo oculta mientras la app siga abierta.
class AvisosInicio extends StatefulWidget {
  final RepositorioAvisos repositorio;
  final String? versionId;
  final DateTime Function() ahora;

  const AvisosInicio({
    super.key,
    required this.repositorio,
    required this.versionId,
    this.ahora = DateTime.now,
  });

  @override
  State<AvisosInicio> createState() => _AvisosInicioState();
}

class _AvisosInicioState extends State<AvisosInicio> {
  late final Future<List<Aviso>> _avisos = widget.repositorio.activos();
  final _ocultos = <String>{};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Aviso>>(
      future: _avisos,
      builder: (context, s) {
        final avisos = avisosPara(
          s.data ?? const [],
          versionId: widget.versionId,
          ahora: widget.ahora(),
        ).where((a) => !_ocultos.contains(a.id)).toList();
        return AnimatedSize(
          duration: sinAnimaciones(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: avisos.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(
                  children: [
                    for (final a in avisos)
                      EntradaDifuminada(
                        key: ValueKey(a.id),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TarjetaAviso(
                            aviso: a,
                            onCerrar: () => setState(() => _ocultos.add(a.id)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
        );
      },
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  final Aviso aviso;
  final VoidCallback onCerrar;

  const _TarjetaAviso({required this.aviso, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final color = aviso.importante ? ColoresApp.naranja : ColoresApp.celeste;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              aviso.importante
                  ? Icons.priority_high_rounded
                  : Icons.campaign_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aviso.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (aviso.mensaje.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    aviso.mensaje,
                    style: const TextStyle(
                      color: ColoresApp.apagado,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ocultar',
            visualDensity: VisualDensity.compact,
            onPressed: onCerrar,
            icon: const Icon(Icons.close, size: 18, color: ColoresApp.apagado),
          ),
        ],
      ),
    );
  }
}
