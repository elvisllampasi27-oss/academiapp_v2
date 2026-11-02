import 'package:flutter/material.dart';

import '../../features/reportes/domain/reporte.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'repositorio_bandeja.dart';

/// Lo que reportan los estudiantes con la bandera de la app, con dónde
/// estaban para ir directo a corregirlo.
class BandejaPage extends StatefulWidget {
  final RepositorioBandeja repositorio;
  final ValueChanged<String> onAbrirEstudiante;

  /// Abre Exámenes en esa pregunta.
  final void Function(String examenId, String? preguntaId) onIrPregunta;

  /// Abre Cursos y temas en ese tema.
  final void Function(String versionId, String temaId) onIrTema;
  final DateTime Function() ahora;

  const BandejaPage({
    super.key,
    required this.repositorio,
    required this.onAbrirEstudiante,
    required this.onIrPregunta,
    required this.onIrTema,
    this.ahora = DateTime.now,
  });

  @override
  State<BandejaPage> createState() => _BandejaPageState();
}

const _respuestasSugeridas = [
  'Gracias, ya corregimos la pregunta.',
  'Gracias, ya cambiamos el video.',
  'Lo revisamos y la clave es correcta.',
];

IconData iconoReporte(TipoReporte tipo) => switch (tipo) {
  TipoReporte.preguntaExamen => Icons.assignment_outlined,
  TipoReporte.preguntaPractica => Icons.quiz_outlined,
  TipoReporte.video => Icons.play_circle_outline,
  TipoReporte.material => Icons.description_outlined,
  TipoReporte.app => Icons.phone_android,
  TipoReporte.otro => Icons.outlined_flag,
};

class _BandejaPageState extends State<BandejaPage> {
  EstadoReporte _estado = EstadoReporte.nuevo;
  late Future<List<Reporte>> _reportes = widget.repositorio.reportes(_estado);
  String? _elegidoId;
  bool _ocupado = false;

  void _cargar(EstadoReporte estado) {
    setState(() {
      _estado = estado;
      _elegidoId = null;
      _reportes = widget.repositorio.reportes(estado);
    });
  }

  Future<void> _cambiar(
    Reporte r,
    EstadoReporte estado, {
    String? respuesta,
  }) async {
    setState(() => _ocupado = true);
    try {
      await widget.repositorio.cambiarEstado(r, estado, respuesta: respuesta);
      if (!mounted) return;
      avisarPanel(context, switch (estado) {
        EstadoReporte.resuelto => 'Reporte resuelto.',
        EstadoReporte.enRevision => 'Reporte en revisión.',
        EstadoReporte.nuevo => 'Reporte reabierto.',
      });
      _cargar(_estado);
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _resolver(Reporte r) async {
    final respuesta = await pedirTexto(
      context,
      titulo: 'Resolver reporte',
      etiqueta: 'Respuesta para el estudiante',
      confirmar: 'Resolver',
      sugerencias: _respuestasSugeridas,
    );
    if (respuesta != null) {
      await _cambiar(r, EstadoReporte.resuelto, respuesta: respuesta);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel<List<Reporte>>(
      futuro: _reportes,
      onReintentar: () => _cargar(_estado),
      builder: (context, lista) {
        final elegido =
            lista.where((r) => r.id == _elegidoId).firstOrNull ??
            lista.firstOrNull;
        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Reportes de la app',
              subtitulo:
                  'Lo que los estudiantes reportan con la bandera: preguntas '
                  'con error, videos que no cargan y fallas de la app.',
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
                  (EstadoReporte.nuevo, 'Nuevos'),
                  (EstadoReporte.enRevision, 'En revisión'),
                  (EstadoReporte.resuelto, 'Resueltos'),
                ])
                  ChoiceChip(
                    label: Text(e == _estado ? '$t · ${lista.length}' : t),
                    selected: _estado == e,
                    onSelected: (_) => _cargar(e),
                  ),
              ],
            ),
            if (elegido == null)
              TarjetaPanel(
                child: Text(
                  _estado == EstadoReporte.nuevo
                      ? 'No hay reportes nuevos. Todo en orden.'
                      : 'No hay reportes aquí.',
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
                    for (final r in lista)
                      _TarjetaReporte(
                        reporte: r,
                        elegido: r.id == elegido.id,
                        ahora: widget.ahora(),
                        onTap: () => setState(() => _elegidoId = r.id),
                      ),
                  ],
                ),
                lateral: _detalle(elegido),
              ),
          ],
        );
      },
    );
  }

  Widget _detalle(Reporte r) {
    final p = PaletaPanel.de(context);
    final c = r.contexto;
    final examenId = c.examenId;
    final versionId = c.versionId;
    final temaId = c.temaId;
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            r.tipo.etiqueta,
            extra: Insignia(
              r.estado.etiqueta,
              tono: switch (r.estado) {
                EstadoReporte.nuevo => TonoInsignia.acento,
                EstadoReporte.enRevision => TonoInsignia.gris,
                EstadoReporte.resuelto => TonoInsignia.secundario,
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PaletaPanel.linea,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(r.mensaje, style: const TextStyle(height: 1.45)),
          ),
          const SizedBox(height: 12),
          FilaDato('Estudiante', r.nombre.isEmpty ? r.correo : r.nombre),
          FilaDato(
            'Enviado',
            '${fechaPanel(r.creadoEn)} · ${haceCuanto(r.creadoEn, widget.ahora())}',
          ),
          if (c.titulo.isNotEmpty) FilaDato('Dónde', c.titulo),
          if (c.preguntaId case final id?) FilaDato('Pregunta', id),
          if (r.respuesta case final respuesta?)
            FilaDato('Respuesta', respuesta),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: () => widget.onAbrirEstudiante(r.usuarioId),
                child: const Text('Ver ficha'),
              ),
              if (examenId != null)
                OutlinedButton.icon(
                  onPressed: () => widget.onIrPregunta(examenId, c.preguntaId),
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text('Ir a la pregunta'),
                ),
              if (versionId != null && temaId != null)
                OutlinedButton.icon(
                  onPressed: () => widget.onIrTema(versionId, temaId),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Ir al tema'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (r.estado == EstadoReporte.nuevo)
                OutlinedButton(
                  onPressed: _ocupado
                      ? null
                      : () => _cambiar(r, EstadoReporte.enRevision),
                  child: const Text('Marcar en revisión'),
                ),
              if (r.estado != EstadoReporte.resuelto)
                FilledButton.icon(
                  onPressed: _ocupado ? null : () => _resolver(r),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Resolver'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _ocupado
                      ? null
                      : () => _cambiar(r, EstadoReporte.nuevo),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Reabrir'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Al resolver, el estudiante ve tu respuesta en "Mis reportes".',
            style: TextStyle(color: p.tenue, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TarjetaReporte extends StatelessWidget {
  final Reporte reporte;
  final bool elegido;
  final DateTime ahora;
  final VoidCallback onTap;

  const _TarjetaReporte({
    required this.reporte,
    required this.elegido,
    required this.ahora,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final titulo = reporte.contexto.titulo;
    return Material(
      color: elegido ? const Color(0x12FFFFFF) : PaletaPanel.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: elegido ? p.acento.withValues(alpha: 0.6) : PaletaPanel.borde,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.acento.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconoReporte(reporte.tipo),
                  color: p.acento,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo.isEmpty
                          ? reporte.tipo.etiqueta
                          : '${reporte.tipo.etiqueta} · $titulo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      reporte.mensaje,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.apagado, fontSize: 13),
                    ),
                    Text(
                      reporte.nombre.isEmpty ? reporte.correo : reporte.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.tenue, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                haceCuanto(reporte.creadoEn, ahora),
                style: TextStyle(color: p.tenue, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
