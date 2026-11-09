import 'package:flutter/material.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/formato_fecha.dart';
import '../domain/en_vivo.dart';
import 'en_vivos.dart';
import 'programar_en_vivo_page.dart';

/// Los en vivos del docente: programar uno nuevo y ver o retirar los que
/// ya envió.
class MisEnVivos extends StatefulWidget {
  final String uid;
  final String nombre;
  final RepositorioEnVivos repositorio;
  final DateTime Function() ahora;

  const MisEnVivos({
    super.key,
    required this.uid,
    required this.nombre,
    required this.repositorio,
    this.ahora = DateTime.now,
  });

  @override
  State<MisEnVivos> createState() => _MisEnVivosState();
}

class _MisEnVivosState extends State<MisEnVivos> {
  late Future<List<EnVivo>> _mios = widget.repositorio.mios(widget.uid);

  void _recargar() {
    setState(() {
      _mios = widget.repositorio.mios(widget.uid);
    });
  }

  void _avisar(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _programar() async {
    final enviado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProgramarEnVivoPage(
          uid: widget.uid,
          nombre: widget.nombre,
          repositorio: widget.repositorio,
          ahora: widget.ahora,
        ),
      ),
    );
    if (enviado != true || !mounted) return;
    _recargar();
    _avisar('En vivo enviado. Lo verán los alumnos al aprobarlo.');
  }

  Future<void> _cancelar(EnVivo e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar en vivo'),
        content: Text('"${e.titulo}" dejará de verse en la app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repositorio.cancelar(e);
      if (mounted) _recargar();
    } catch (_) {
      if (mounted) _avisar('No se pudo retirar. Revisa tu conexión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mis en vivos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: _programar,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Programar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FutureBuilder<List<EnVivo>>(
          future: _mios,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            final mios = s.data ?? const [];
            if (s.hasError || mios.isEmpty) {
              return Text(
                s.hasError
                    ? 'No se pudieron cargar tus en vivos.'
                    : 'Todavía no programaste ninguno.',
                style: const TextStyle(color: ColoresApp.apagado),
              );
            }
            final ahora = widget.ahora();
            return Column(
              children: [
                for (final e in mios)
                  Card(
                    child: ListTile(
                      leading: Icon(iconoPlataforma(e.plataforma)),
                      title: Text(e.titulo),
                      subtitle: Text(
                        [
                          '${fechaCorta(e.inicio)} · ${horaCorta(e.inicio)}',
                          ?e.motivo,
                        ].join('\n'),
                      ),
                      isThreeLine: e.motivo != null,
                      trailing: e.momento(ahora) == MomentoEnVivo.terminado
                          ? const Text(
                              'Terminado',
                              style: TextStyle(color: ColoresApp.tenue),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  e.estado.etiqueta,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: switch (e.estado) {
                                      EstadoEnVivo.pendiente =>
                                        ColoresApp.ambar,
                                      EstadoEnVivo.aprobado =>
                                        ColoresApp.celeste,
                                      EstadoEnVivo.rechazado =>
                                        ColoresApp.naranja,
                                    },
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Retirar',
                                  onPressed: () => _cancelar(e),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
