import 'package:flutter/material.dart';

import '../animacion_panel.dart';
import '../../features/teachers/domain/clase_docente.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'docentes_page.dart';
import 'repositorio_clases_docentes_admin.dart';

const _motivosSugeridos = [
  'El video no corresponde al tema.',
  'El video no se puede ver.',
  'El audio o la imagen no se entienden.',
];

/// Clases que envían los docentes aprobados: se mira el video y se
/// publica (lo ven los alumnos del tema) o no.
class ClasesDocentesPage extends StatefulWidget {
  final RepositorioClasesDocentesAdmin repositorio;
  final AbrirEnlacePanel abrirEnlace;
  final DateTime Function() ahora;

  const ClasesDocentesPage({
    super.key,
    required this.repositorio,
    this.abrirEnlace = abrirEnPestana,
    this.ahora = DateTime.now,
  });

  @override
  State<ClasesDocentesPage> createState() => _ClasesDocentesPageState();
}

class _ClasesDocentesPageState extends State<ClasesDocentesPage> {
  EstadoClaseDocente _estado = EstadoClaseDocente.pendiente;
  late Future<List<ClaseDocente>> _lista = widget.repositorio.clases(_estado);
  String? _elegidaId;
  bool _ocupado = false;

  void _cargar(EstadoClaseDocente estado) {
    setState(() {
      _estado = estado;
      _elegidaId = null;
      _lista = widget.repositorio.clases(estado);
    });
  }

  Future<void> _hacer(Future<void> Function() accion, String hecho) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (!mounted) return;
      avisarPanel(context, hecho);
      _cargar(_estado);
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _rechazar(ClaseDocente c) async {
    final ocultar = c.estado == EstadoClaseDocente.aprobada;
    final motivo = await pedirTexto(
      context,
      titulo: ocultar ? 'Ocultar clase' : 'No publicar',
      etiqueta: 'Motivo (lo ve el docente)',
      confirmar: ocultar ? 'Ocultar' : 'No publicar',
      sugerencias: _motivosSugeridos,
    );
    if (motivo == null) return;
    await _hacer(
      () => widget.repositorio.rechazar(c, motivo),
      ocultar ? 'Clase oculta.' : 'Clase no publicada.',
    );
  }

  Future<void> _ver(ClaseDocente c) async {
    final abierto = await widget.abrirEnlace(c.enlace);
    if (!abierto && mounted) avisarPanel(context, 'No se pudo abrir el video.');
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel<List<ClaseDocente>>(
      futuro: _lista,
      onReintentar: () => _cargar(_estado),
      builder: (context, lista) {
        final elegida =
            lista.where((c) => c.id == _elegidaId).firstOrNull ??
            lista.firstOrNull;
        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Clases de docentes',
              subtitulo:
                  'Videos de YouTube que envían los docentes aprobados. Mira '
                  'cada uno antes de publicarlo.',
              acciones: [
                OutlinedButton.icon(
                  onPressed: () => _cargar(_estado),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (e, t) in const [
                  (EstadoClaseDocente.pendiente, 'Por revisar'),
                  (EstadoClaseDocente.aprobada, 'Publicadas'),
                  (EstadoClaseDocente.rechazada, 'No publicadas'),
                ])
                  ChoiceChip(
                    label: Text(e == _estado ? '$t · ${lista.length}' : t),
                    selected: _estado == e,
                    onSelected: (_) => _cargar(e),
                  ),
              ],
            ),
            if (elegida == null)
              TarjetaPanel(
                child: Text(
                  _estado == EstadoClaseDocente.pendiente
                      ? 'No hay clases por revisar.'
                      : 'No hay clases aquí.',
                  style: TextStyle(color: PaletaPanel.de(context).apagado),
                ),
              )
            else
              DosColumnas(
                flexPrincipal: 5,
                flexLateral: 4,
                principal: ColumnaPanel(
                  espacio: 10,
                  children: [
                    for (final (i, c) in lista.indexed)
                      FilaEntrante(
                        indice: i,
                        child: _FilaClase(
                          clase: c,
                          elegida: c.id == elegida.id,
                          ahora: widget.ahora(),
                          onTap: () => setState(() => _elegidaId = c.id),
                        ),
                      ),
                  ],
                ),
                lateral: _detalle(elegida),
              ),
          ],
        );
      },
    );
  }

  Widget _detalle(ClaseDocente c) {
    final p = PaletaPanel.de(context);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            c.titulo,
            extra: Insignia(
              c.estado.etiqueta,
              tono: switch (c.estado) {
                EstadoClaseDocente.pendiente => TonoInsignia.acento,
                EstadoClaseDocente.aprobada => TonoInsignia.secundario,
                EstadoClaseDocente.rechazada => TonoInsignia.gris,
              },
            ),
          ),
          InkWell(
            onTap: () => _ver(c),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      c.miniatura,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: PaletaPanel.linea),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 48,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilaDato('Docente', c.docenteNombre),
          FilaDato(
            'Tema',
            [
              c.cursoNombre,
              c.temaTitulo,
            ].where((t) => t.isNotEmpty).join(' · '),
          ),
          FilaDato('Corazones', '${c.corazones}'),
          FilaDato(
            'Enviada',
            '${fechaPanel(c.creadaEn)} · ${haceCuanto(c.creadaEn, widget.ahora())}',
          ),
          if (c.motivo case final motivo?) FilaDato('Motivo', motivo),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _ver(c),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ver en YouTube'),
              ),
              if (c.estado != EstadoClaseDocente.aprobada)
                FilledButton.icon(
                  onPressed: _ocupado
                      ? null
                      : () => _hacer(
                          () => widget.repositorio.publicar(c),
                          'Clase publicada.',
                        ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Publicar'),
                ),
              if (c.estado != EstadoClaseDocente.rechazada)
                OutlinedButton(
                  onPressed: _ocupado ? null : () => _rechazar(c),
                  child: Text(
                    c.estado == EstadoClaseDocente.aprobada
                        ? 'Ocultar'
                        : 'No publicar',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Si la reportan los alumnos, el reporte llega a "Reportes de la '
            'app".',
            style: TextStyle(color: p.tenue, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FilaClase extends StatelessWidget {
  final ClaseDocente clase;
  final bool elegida;
  final DateTime ahora;
  final VoidCallback onTap;

  const _FilaClase({
    required this.clase,
    required this.elegida,
    required this.ahora,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final c = clase;
    return Material(
      color: elegida ? const Color(0x12FFFFFF) : PaletaPanel.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: elegida ? p.acento.withValues(alpha: 0.6) : PaletaPanel.borde,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 96,
                  height: 54,
                  child: Image.network(
                    c.miniatura,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: PaletaPanel.linea),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${c.docenteNombre} · ${c.temaTitulo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.apagado, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                c.estado == EstadoClaseDocente.aprobada
                    ? '♥ ${c.corazones}'
                    : haceCuanto(c.creadaEn, ahora),
                style: TextStyle(color: p.tenue, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
