import 'package:flutter/material.dart';

import '../../domain/entities/item_mi_ruta.dart';
import '../../domain/entities/recomendacion.dart';
import '../../domain/services/construir_mi_ruta_service.dart';

/// Nombre visible de un tema (y su curso) a partir de su ID.
typedef DescribirTema = ({String titulo, String? curso})? Function(
  String temaId,
);

class MiRutaPage extends StatefulWidget {
  final ConstruirMiRutaService service;
  final String usuarioId;
  final String matriculaId;
  final DescribirTema describirTema;
  final void Function(String temaId)? onAbrirTema;

  const MiRutaPage({
    super.key,
    required this.service,
    required this.usuarioId,
    required this.matriculaId,
    required this.describirTema,
    this.onAbrirTema,
  });

  @override
  State<MiRutaPage> createState() => _MiRutaPageState();
}

class _MiRutaPageState extends State<MiRutaPage> {
  late Future<List<ItemMiRuta>> _ruta;

  @override
  void initState() {
    super.initState();
    _ruta = _cargar();
  }

  Future<List<ItemMiRuta>> _cargar() => widget.service.construir(
    usuarioId: widget.usuarioId,
    matriculaId: widget.matriculaId,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Ruta')),
      body: FutureBuilder<List<ItemMiRuta>>(
        future: _ruta,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar tu ruta.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _ruta = _cargar();
                      });
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data!;

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay datos. Resuelve prácticas de tus temas '
                  'y aquí verás qué reforzar, practicar o profundizar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final tipo in TipoRecomendacion.values)
                ..._seccion(
                  tipo,
                  items.where((i) => i.recomendacion.tipo == tipo).toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _seccion(TipoRecomendacion tipo, List<ItemMiRuta> items) {
    if (items.isEmpty) return const [];

    final colores = Theme.of(context).colorScheme;
    final (titulo, color, icono) = switch (tipo) {
      TipoRecomendacion.reforzar => (
        'Reforzar',
        colores.error,
        Icons.priority_high,
      ),
      TipoRecomendacion.practicar => (
        'Practicar',
        colores.tertiary,
        Icons.fitness_center,
      ),
      TipoRecomendacion.profundizar => (
        'Profundizar',
        colores.primary,
        Icons.trending_up,
      ),
    };

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Row(
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
      for (final item in items) _tarjeta(item, color),
    ];
  }

  Widget _tarjeta(ItemMiRuta item, Color color) {
    final temaId = item.temaId;
    final descripcion = temaId == null ? null : widget.describirTema(temaId);
    final porcentaje = (item.estado.valor * 100).round();
    final abrir = widget.onAbrirTema;

    return Card(
      child: ListTile(
        title: Text(descripcion?.titulo ?? item.estado.habilidadId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (descripcion?.curso != null) Text(descripcion!.curso!),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: item.estado.valor,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 4),
            Text(
              'Dominio estimado $porcentaje % · '
              '${item.cantidadEvidencias} respuesta'
              '${item.cantidadEvidencias == 1 ? '' : 's'}',
            ),
          ],
        ),
        trailing: temaId != null && abrir != null
            ? const Icon(Icons.chevron_right)
            : null,
        onTap: temaId != null && abrir != null ? () => abrir(temaId) : null,
      ),
    );
  }
}
