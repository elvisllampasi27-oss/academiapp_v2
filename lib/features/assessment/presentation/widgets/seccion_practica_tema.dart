import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../domain/entities/evaluacion.dart';
import '../../domain/services/practica_tema_service.dart';
import '../pages/practica_page.dart';
import '../../../../core/presentation/animaciones.dart';

/// Bloque "Quiz del tema" dentro de la pantalla del tema. Siempre se puede
/// empezar; si [claseVista] es false, antes pregunta si quiere darlo sin
/// terminar la clase.
class SeccionPracticaTema extends StatefulWidget {
  final PracticaTemaService service;
  final String temaId;
  final String versionId;
  final String tituloTema;
  final bool claseVista;

  const SeccionPracticaTema({
    super.key,
    required this.service,
    required this.temaId,
    required this.versionId,
    required this.tituloTema,
    this.claseVista = true,
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

  Future<void> _empezar(Evaluacion practica) async {
    if (!widget.claseVista) {
      final darlo = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aún no terminas la clase'),
          content: const Text(
            '¿Seguro que quieres dar el quiz sin terminar de ver la clase?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ver la clase'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dar el quiz'),
            ),
          ],
        ),
      );
      if (darlo != true || !mounted) return;
    }
    await Navigator.of(context).push(
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

        return EntradaDifuminada(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quiz del tema',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (snapshot.hasError)
                    const Text('No se pudieron cargar las prácticas.')
                  else if (practicas.isEmpty)
                    const Text(
                      'Todavía no hay quiz para este tema.',
                      style: TextStyle(color: ColoresApp.apagado),
                    )
                  else
                    for (final practica in practicas)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${etiquetaNivel(practica.nivel)} · '
                                'corrección al instante',
                                style: const TextStyle(
                                  color: ColoresApp.apagado,
                                ),
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
          ),
        );
      },
    );
  }
}
