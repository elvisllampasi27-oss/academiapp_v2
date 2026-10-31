import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/contenido.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/material_tema.dart';
import '../../domain/entities/recurso.dart';
import '../../domain/entities/tema.dart';
import '../../domain/services/obtener_material_tema_service.dart';
import '../utils/enlace_recurso.dart';

typedef AbrirEnlace = Future<bool> Function(Uri enlace);

Future<bool> _abrirEnNavegador(Uri enlace) =>
    launchUrl(enlace, mode: LaunchMode.externalApplication);

class TemaPage extends StatefulWidget {
  final Tema tema;
  final Curso? curso;
  final String versionId;
  final ObtenerMaterialTemaService service;

  /// Inyectable para pruebas; por defecto abre en el navegador/app externa.
  final AbrirEnlace abrirEnlace;

  /// Bloque adicional al final (p. ej. "Practicar"). Lo compone quien abre
  /// la pantalla, así el módulo académico no depende del de evaluación.
  final Widget? seccionExtra;

  const TemaPage({
    super.key,
    required this.tema,
    required this.curso,
    required this.versionId,
    required this.service,
    this.abrirEnlace = _abrirEnNavegador,
    this.seccionExtra,
  });

  @override
  State<TemaPage> createState() => _TemaPageState();
}

class _TemaPageState extends State<TemaPage> {
  late Future<MaterialTema> _material;

  @override
  void initState() {
    super.initState();
    _material = _cargar();
  }

  Future<MaterialTema> _cargar() => widget.service.obtener(
    temaId: widget.tema.id,
    versionId: widget.versionId,
  );

  Future<void> _abrir(Recurso recurso) async {
    final enlace = enlaceDeRecurso(recurso);
    final abierto = enlace != null && await widget.abrirEnlace(enlace);

    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir este material.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = widget.tema;

    return Scaffold(
      appBar: AppBar(title: Text(widget.curso?.nombre ?? 'Tema')),
      body: FutureBuilder<MaterialTema>(
        future: _material,
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Tema ${tema.orden}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Text(
                tema.titulo,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (tema.descripcion != null) ...[
                const SizedBox(height: 8),
                Text(tema.descripcion!),
              ],
              const SizedBox(height: 24),
              ..._cuerpo(snapshot),
              ?widget.seccionExtra,
            ],
          );
        },
      ),
    );
  }

  List<Widget> _cuerpo(AsyncSnapshot<MaterialTema> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const [Center(child: CircularProgressIndicator())];
    }

    if (snapshot.hasError) {
      return [
        const Text('No se pudo cargar el material del tema.'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _material = _cargar();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ];
    }

    final material = snapshot.data!;

    if (material.estaVacio) {
      return const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'El material de este tema se está preparando.',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ];
    }

    return [
      if (material.contenidos.isNotEmpty) ...[
        const _TituloSeccion('Qué aprenderás'),
        for (final contenido in material.contenidos) _FilaContenido(contenido),
        const SizedBox(height: 24),
      ],
      if (material.recursos.isNotEmpty) ...[
        const _TituloSeccion('Material'),
        for (final recurso in material.recursos)
          Card(
            child: ListTile(
              leading: Icon(_iconoDe(recurso.tipo)),
              title: Text(recurso.titulo),
              subtitle: Text(_etiquetaDe(recurso.tipo)),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _abrir(recurso),
            ),
          ),
      ],
    ];
  }

  static IconData _iconoDe(TipoRecurso tipo) => switch (tipo) {
    TipoRecurso.video => Icons.play_circle_outline,
    TipoRecurso.pdf => Icons.picture_as_pdf_outlined,
    TipoRecurso.teoria => Icons.menu_book_outlined,
    TipoRecurso.ejemplo => Icons.lightbulb_outline,
    TipoRecurso.ejercicio => Icons.edit_note,
    TipoRecurso.grabacion => Icons.videocam_outlined,
  };

  static String _etiquetaDe(TipoRecurso tipo) => switch (tipo) {
    TipoRecurso.video => 'Video',
    TipoRecurso.pdf => 'PDF',
    TipoRecurso.teoria => 'Teoría',
    TipoRecurso.ejemplo => 'Ejemplo',
    TipoRecurso.ejercicio => 'Ejercicios',
    TipoRecurso.grabacion => 'Grabación',
  };
}

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FilaContenido extends StatelessWidget {
  final Contenido contenido;

  const _FilaContenido(this.contenido);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${contenido.orden}.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contenido.nombre),
                if (contenido.descripcion != null)
                  Text(
                    contenido.descripcion!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
