import 'package:flutter/material.dart';

import '../../domain/entities/evaluacion.dart';
import '../../domain/services/practica_tema_service.dart';
import '../pages/practica_page.dart';

/// Bloque "Practicar" que se muestra dentro de la pantalla del tema.
class SeccionPracticaTema extends StatefulWidget {
  final PracticaTemaService service;
  final String temaId;
  final String versionId;
  final String tituloTema;

  const SeccionPracticaTema({
    super.key,
    required this.service,
    required this.temaId,
    required this.versionId,
    required this.tituloTema,
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
    'basica' => 'Práctica básica',
    'intermedia' => 'Práctica intermedia',
    'avanzada' => 'Práctica avanzada',
    _ => 'Práctica',
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Evaluacion>>(
      future: _practicas,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }

        final practicas = snapshot.data ?? const [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Practicar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (snapshot.hasError)
              const Text('No se pudieron cargar las prácticas.')
            else if (practicas.isEmpty)
              const Text('Todavía no hay prácticas para este tema.')
            else
              for (final practica in practicas)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.quiz_outlined),
                    title: Text(etiquetaNivel(practica.nivel)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PracticaPage(
                          service: widget.service,
                          evaluacion: practica,
                          titulo: etiquetaNivel(practica.nivel),
                          subtitulo: widget.tituloTema,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
