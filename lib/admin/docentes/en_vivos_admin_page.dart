import 'package:flutter/material.dart';

import '../animacion_panel.dart';
import '../../core/presentation/formato_fecha.dart';
import '../../features/teachers/domain/en_vivo.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'docentes_page.dart';
import 'repositorio_en_vivos_admin.dart';

const _motivosSugeridos = [
  'El enlace no abre.',
  'El tema no corresponde a la preparación.',
  'Elige otro horario, por favor.',
];

String _momento(EnVivo e, DateTime ahora) => switch (e.momento(ahora)) {
  MomentoEnVivo.proximo => 'Próximo',
  MomentoEnVivo.enVivo => 'En vivo ahora',
  MomentoEnVivo.terminado => 'Terminado',
};

/// En vivos que programan los docentes. Al aprobar uno, los alumnos lo ven
/// en Inicio con cuenta regresiva y, a la hora, el botón para unirse.
class EnVivosAdminPage extends StatefulWidget {
  final RepositorioEnVivosAdmin repositorio;
  final AbrirEnlacePanel abrirEnlace;
  final DateTime Function() ahora;

  const EnVivosAdminPage({
    super.key,
    required this.repositorio,
    this.abrirEnlace = abrirEnPestana,
    this.ahora = DateTime.now,
  });

  @override
  State<EnVivosAdminPage> createState() => _EnVivosAdminPageState();
}

class _EnVivosAdminPageState extends State<EnVivosAdminPage> {
  EstadoEnVivo _estado = EstadoEnVivo.pendiente;
  late Future<List<EnVivo>> _lista = widget.repositorio.enVivos(_estado);
  String? _elegidoId;
  bool _ocupado = false;

  void _cargar(EstadoEnVivo estado) {
    setState(() {
      _estado = estado;
      _elegidoId = null;
      _lista = widget.repositorio.enVivos(estado);
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

  Future<void> _rechazar(EnVivo e) async {
    final quitar = e.estado == EstadoEnVivo.aprobado;
    final motivo = await pedirTexto(
      context,
      titulo: quitar ? 'Quitar en vivo' : 'No aprobar',
      etiqueta: 'Motivo (lo ve el docente)',
      confirmar: quitar ? 'Quitar' : 'No aprobar',
      sugerencias: _motivosSugeridos,
    );
    if (motivo == null) return;
    await _hacer(
      () => widget.repositorio.rechazar(e, motivo),
      quitar ? 'En vivo quitado.' : 'En vivo no aprobado.',
    );
  }

  Future<void> _terminar(EnVivo e) async {
    final ok = await confirmarPanel(
      context,
      titulo: 'Terminar en vivo',
      mensaje: '"${e.titulo}" dejará de verse en la app desde ahora.',
      confirmar: 'Terminar',
      peligro: true,
    );
    if (ok) {
      await _hacer(() => widget.repositorio.terminar(e), 'En vivo terminado.');
    }
  }

  Future<void> _abrir(EnVivo e) async {
    final uri = Uri.tryParse(e.enlace);
    final abierto = uri != null && await widget.abrirEnlace(uri);
    if (!abierto && mounted) {
      avisarPanel(context, 'No se pudo abrir el enlace.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel<List<EnVivo>>(
      futuro: _lista,
      onReintentar: () => _cargar(_estado),
      builder: (context, lista) {
        final elegido =
            lista.where((e) => e.id == _elegidoId).firstOrNull ??
            lista.firstOrNull;
        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'En vivos de docentes',
              subtitulo:
                  'Al aprobar uno, los alumnos lo ven en Inicio con cuenta '
                  'regresiva y, a la hora, el botón para unirse.',
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
                  (EstadoEnVivo.pendiente, 'Por revisar'),
                  (EstadoEnVivo.aprobado, 'Aprobados'),
                  (EstadoEnVivo.rechazado, 'No aprobados'),
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
                  _estado == EstadoEnVivo.pendiente
                      ? 'No hay en vivos por revisar.'
                      : 'No hay en vivos aquí.',
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
                    for (final (i, e) in lista.indexed)
                      FilaEntrante(
                        indice: i,
                        child: _FilaEnVivo(
                          enVivo: e,
                          elegido: e.id == elegido.id,
                          ahora: widget.ahora(),
                          onTap: () => setState(() => _elegidoId = e.id),
                        ),
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

  Widget _detalle(EnVivo e) {
    final p = PaletaPanel.de(context);
    final ahora = widget.ahora();
    final momento = e.momento(ahora);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            e.titulo,
            extra: Insignia(
              e.estado == EstadoEnVivo.aprobado
                  ? _momento(e, ahora)
                  : e.estado.etiqueta,
              tono: switch (e.estado) {
                EstadoEnVivo.pendiente => TonoInsignia.acento,
                EstadoEnVivo.aprobado =>
                  momento == MomentoEnVivo.terminado
                      ? TonoInsignia.gris
                      : TonoInsignia.secundario,
                EstadoEnVivo.rechazado => TonoInsignia.gris,
              },
            ),
          ),
          FilaDato('Docente', e.docenteNombre),
          FilaDato('Plataforma', e.plataforma.etiqueta),
          FilaDato('Día', fechaCorta(e.inicio)),
          FilaDato('Horario', '${horaCorta(e.inicio)} a ${horaCorta(e.fin)}'),
          if (e.cursoNombre case final curso?) FilaDato('Curso', curso),
          if (e.motivo case final motivo?) FilaDato('Motivo', motivo),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _abrir(e),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(e.enlace, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (e.estado != EstadoEnVivo.aprobado &&
                  momento != MomentoEnVivo.terminado)
                FilledButton.icon(
                  onPressed: _ocupado
                      ? null
                      : () => _hacer(
                          () => widget.repositorio.aprobar(e),
                          'En vivo aprobado.',
                        ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Aprobar'),
                ),
              if (e.estado != EstadoEnVivo.rechazado &&
                  momento != MomentoEnVivo.terminado)
                OutlinedButton(
                  onPressed: _ocupado ? null : () => _rechazar(e),
                  child: Text(
                    e.estado == EstadoEnVivo.aprobado ? 'Quitar' : 'No aprobar',
                  ),
                ),
              if (e.estado == EstadoEnVivo.aprobado &&
                  momento == MomentoEnVivo.enVivo)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.alerta,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _ocupado ? null : () => _terminar(e),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Terminar ahora'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'No se puede saber si de verdad está transmitiendo: la app lo '
            'muestra "en vivo" durante su horario. Si algo sale mal, '
            'termínalo desde aquí.',
            style: TextStyle(color: p.tenue, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _FilaEnVivo extends StatelessWidget {
  final EnVivo enVivo;
  final bool elegido;
  final DateTime ahora;
  final VoidCallback onTap;

  const _FilaEnVivo({
    required this.enVivo,
    required this.elegido,
    required this.ahora,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final e = enVivo;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${e.docenteNombre} · ${e.plataforma.etiqueta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.apagado, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                e.momento(ahora) == MomentoEnVivo.enVivo
                    ? '● En vivo'
                    : '${fechaCorta(e.inicio)} · ${horaCorta(e.inicio)}',
                style: TextStyle(color: p.tenue, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
