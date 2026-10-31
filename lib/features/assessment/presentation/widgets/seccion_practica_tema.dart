import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../domain/entities/evaluacion.dart';
import '../../domain/services/practica_tema_service.dart';
import '../pages/practica_page.dart';

/// Bloque "Quiz del tema" dentro de la pantalla del tema.
/// Mientras [habilitada] sea false (la clase no se terminó) no se puede
/// empezar.
class SeccionPracticaTema extends StatefulWidget {
  final PracticaTemaService service;
  final String temaId;
  final String versionId;
  final String tituloTema;
  final bool habilitada;

  const SeccionPracticaTema({
    super.key,
    required this.service,
    required this.temaId,
    required this.versionId,
    required this.tituloTema,
    this.habilitada = true,
  });

  @override
  State<SeccionPracticaTema> createState() => _SeccionPracticaTemaState();
}

class _SeccionPracticaTemaState extends State<SeccionPracticaTema> {
  late final Future<List<Evaluacion>> _practicas = widget.service.listar(
    temaId: widget.temaId,
    versionId: widget.versionId,
  );

  static String etiquetaNivel(String? nivel) => switch (nivel) {
    'basica' => 'Básico',
    'intermedia' => 'Intermedio',
    'avanzada' => 'Avanzado',
    _ => 'Práctica',
  };

  void _empezar(Evaluacion practica) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticaPage(
          service: widget.service,
          evaluacion: practica,
          titulo: 'Quiz · ${etiquetaNivel(practica.nivel)}',
          subtitulo: widget.tituloTema,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Evaluacion>>(
      future: _practicas,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        final practicas = snapshot.data ?? const [];
        final disponible =
            widget.habilitada && !snapshot.hasError && practicas.isNotEmpty;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Quiz del tema',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (disponible) const _Etiqueta('Disponible'),
                  ],
                ),
                const SizedBox(height: 10),
                if (snapshot.hasError)
                  const Text('No se pudieron cargar las prácticas.')
                else if (practicas.isEmpty)
                  const Text(
                    'Todavía no hay quiz para este tema.',
                    style: TextStyle(color: ColoresApp.apagado),
                  )
                else if (!widget.habilitada) ...[
                  const Text(
                    'Termina la clase para activar el quiz.',
                    style: TextStyle(color: ColoresApp.apagado),
                  ),
                  const SizedBox(height: 12),
                  const FilledButton(
                    onPressed: null,
                    child: Text('Empezar quiz'),
                  ),
                ] else
                  for (final practica in practicas)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${etiquetaNivel(practica.nivel)} · '
                              'corrección al instante',
                              style: const TextStyle(color: ColoresApp.apagado),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () => _empezar(practica),
                            child: const Text('Empezar quiz'),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;

  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ColoresApp.ambar.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: ColoresApp.ambar,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
