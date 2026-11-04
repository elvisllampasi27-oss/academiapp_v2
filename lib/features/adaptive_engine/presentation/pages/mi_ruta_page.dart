import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/desplegables.dart';
import '../../../../core/presentation/esqueleto.dart';

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

  /// "Mi Ruta" cuando se abre aparte; "Progreso" cuando es una pestaña.
  final String titulo;

  /// Va arriba de todo (en Progreso: la gráfica de notas semanales).
  final Widget? encabezado;

  const MiRutaPage({
    super.key,
    required this.service,
    required this.usuarioId,
    required this.matriculaId,
    required this.describirTema,
    this.onAbrirTema,
    this.titulo = 'Mi Ruta',
    this.encabezado,
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
      appBar: AppBar(title: Text(widget.titulo)),
      body: FutureBuilder<List<ItemMiRuta>>(
        future: _ruta,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const EsqueletoLista(tarjetas: 4);
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
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                ?widget.encabezado,
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no hay datos. Resuelve prácticas de tus temas '
                    'y aquí verás qué reforzar, practicar o profundizar.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              ?widget.encabezado,
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

    final (titulo, color, icono) = switch (tipo) {
      TipoRecomendacion.reforzar => (
        'Reforzar',
        ColoresApp.naranja,
        Icons.priority_high,
      ),
      TipoRecomendacion.practicar => (
        'Practicar',
        ColoresApp.ambar,
        Icons.fitness_center,
      ),
      TipoRecomendacion.profundizar => (
        'Profundizar',
        ColoresApp.celeste,
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
            Flexible(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
      for (final (i, item) in items.indexed)
        Aparecer(indice: i, child: _tarjeta(item, color)),
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
            // La barra se llena desde cero al entrar.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: item.estado.valor),
              duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                  ? Duration.zero
                  : const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, valor, _) => LinearProgressIndicator(
                value: valor,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
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
