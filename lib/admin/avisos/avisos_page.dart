import 'package:flutter/material.dart';

import '../animacion_panel.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../../features/avisos/domain/aviso.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'repositorio_avisos_admin.dart';

/// Avisos que se ven arriba del Inicio de la app.
class AvisosPage extends StatefulWidget {
  final RepositorioAvisosAdmin repositorio;

  /// Para elegir a qué versión va el aviso.
  final Future<List<VersionAcademica>> Function() versiones;
  final DateTime Function() ahora;

  const AvisosPage({
    super.key,
    required this.repositorio,
    required this.versiones,
    this.ahora = DateTime.now,
  });

  @override
  State<AvisosPage> createState() => _AvisosPageState();
}

typedef _Datos = (List<Aviso>, List<VersionAcademica>);

class _AvisosPageState extends State<AvisosPage> {
  late Future<_Datos> _datos = _cargar();
  bool _ocupado = false;

  Future<_Datos> _cargar() =>
      (widget.repositorio.avisos(), widget.versiones()).wait;

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  Future<void> _hacer(Future<void> Function() accion, String hecho) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (!mounted) return;
      avisarPanel(context, hecho);
      _recargar();
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _editar(List<VersionAcademica> versiones, [Aviso? aviso]) async {
    final nuevo = aviso == null;
    final resultado = await showDialog<Aviso>(
      context: context,
      builder: (_) => DialogoAviso(
        aviso: aviso,
        versiones: versiones,
        ahora: widget.ahora(),
      ),
    );
    if (resultado == null) return;
    await _hacer(
      () => widget.repositorio.guardar(resultado, nuevo: nuevo),
      nuevo ? 'Aviso publicado.' : 'Aviso guardado.',
    );
  }

  Future<void> _pausar(Aviso a) => _hacer(
    () => widget.repositorio.guardar(a.copiar(activo: !a.activo), nuevo: false),
    a.activo ? 'Aviso pausado.' : 'Aviso reanudado.',
  );

  Future<void> _eliminar(Aviso a) async {
    final ok = await confirmarPanel(
      context,
      titulo: 'Eliminar aviso',
      mensaje:
          '"${a.titulo}" deja de verse en la app y no se puede recuperar. '
          'Si solo quieres ocultarlo un tiempo, mejor páusalo.',
      confirmar: 'Eliminar',
      peligro: true,
    );
    if (ok) {
      await _hacer(() => widget.repositorio.eliminar(a), 'Aviso eliminado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel<_Datos>(
      futuro: _datos,
      onReintentar: _recargar,
      builder: (context, datos) {
        final (avisos, versiones) = datos;
        final ahora = widget.ahora();
        final vigentes = avisos.where((a) => a.vigenteEn(ahora)).length;
        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Avisos',
              subtitulo:
                  'Mensajes cortos que los estudiantes ven arriba del Inicio: '
                  'feriados, cambios de horario, simulacros nuevos.',
              acciones: [
                FilledButton.icon(
                  onPressed: _ocupado ? null : () => _editar(versiones),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo aviso'),
                ),
              ],
            ),
            DosColumnas(
              flexPrincipal: 5,
              flexLateral: 2,
              principal: avisos.isEmpty
                  ? TarjetaPanel(
                      child: Text(
                        'Todavía no hay avisos.',
                        style: TextStyle(
                          color: PaletaPanel.de(context).apagado,
                        ),
                      ),
                    )
                  : ColumnaPanel(
                      espacio: 12,
                      children: [
                        for (final (iFila, a) in avisos.indexed)
                          FilaEntrante(
                            indice: iFila,
                            child: _TarjetaAviso(
                              aviso: a,
                              version: versiones
                                  .where((v) => v.id == a.versionId)
                                  .firstOrNull,
                              ahora: ahora,
                              ocupado: _ocupado,
                              onEditar: () => _editar(versiones, a),
                              onPausar: () => _pausar(a),
                              onEliminar: () => _eliminar(a),
                            ),
                          ),
                      ],
                    ),
              lateral: TarjetaPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TituloTarjeta('En la app'),
                    FilaDato('Se ven ahora', '$vigentes'),
                    FilaDato('En total', '${avisos.length}'),
                    const SizedBox(height: 12),
                    Text(
                      'Los importantes van primero. Cada estudiante puede '
                      'ocultar uno con la X; vuelve a verlo al abrir la app '
                      'de nuevo. Al vencer la fecha deja de verse solo.',
                      style: TextStyle(
                        color: PaletaPanel.de(context).tenue,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  final Aviso aviso;
  final VersionAcademica? version;
  final DateTime ahora;
  final bool ocupado;
  final VoidCallback onEditar;
  final VoidCallback onPausar;
  final VoidCallback onEliminar;

  const _TarjetaAviso({
    required this.aviso,
    required this.version,
    required this.ahora,
    required this.ocupado,
    required this.onEditar,
    required this.onPausar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final (estado, tono) = !aviso.activo
        ? ('Pausado', TonoInsignia.gris)
        : aviso.vigenteEn(ahora)
        ? ('Se ve en la app', TonoInsignia.secundario)
        : ('Vencido', TonoInsignia.gris);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Insignia(estado, tono: tono),
              if (aviso.importante)
                const Insignia('Importante', tono: TonoInsignia.alerta),
              Insignia(
                aviso.versionId == null
                    ? 'Para todos'
                    : (version?.nombre ?? aviso.versionId!),
              ),
              Insignia('Hasta ${fechaBreve(aviso.hasta)}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            aviso.titulo,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (aviso.mensaje.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              aviso.mensaje,
              style: TextStyle(color: p.apagado, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: ocupado ? null : onEditar,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: ocupado ? null : onPausar,
                icon: Icon(
                  aviso.activo ? Icons.pause : Icons.play_arrow,
                  size: 16,
                ),
                label: Text(aviso.activo ? 'Pausar' : 'Reanudar'),
              ),
              TextButton.icon(
                onPressed: ocupado ? null : onEliminar,
                style: TextButton.styleFrom(foregroundColor: p.alerta),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Crear o editar un aviso. Devuelve el aviso listo para guardar.
class DialogoAviso extends StatefulWidget {
  final Aviso? aviso;
  final List<VersionAcademica> versiones;
  final DateTime ahora;

  const DialogoAviso({
    super.key,
    required this.versiones,
    required this.ahora,
    this.aviso,
  });

  @override
  State<DialogoAviso> createState() => _DialogoAvisoState();
}

class _DialogoAvisoState extends State<DialogoAviso> {
  late final _titulo = TextEditingController(text: widget.aviso?.titulo);
  late final _mensaje = TextEditingController(text: widget.aviso?.mensaje);
  late String? _versionId = widget.aviso?.versionId;
  late bool _importante = widget.aviso?.importante ?? false;

  /// Por defecto, una semana; se muestra hasta el final de ese día.
  late DateTime _hasta =
      widget.aviso?.hasta ??
      DateTime(
        widget.ahora.year,
        widget.ahora.month,
        widget.ahora.day + 7,
        23,
        59,
      );

  @override
  void dispose() {
    _titulo.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime(
      widget.ahora.year,
      widget.ahora.month,
      widget.ahora.day,
    );
    final dia = await showDatePicker(
      context: context,
      initialDate: _hasta.isBefore(hoy) ? hoy : _hasta,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
    );
    if (dia != null) {
      setState(() => _hasta = DateTime(dia.year, dia.month, dia.day, 23, 59));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listo = _titulo.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.aviso == null ? 'Nuevo aviso' : 'Editar aviso'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titulo,
              autofocus: true,
              maxLength: largoTituloAviso,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej.: El lunes no hay clase',
              ),
            ),
            TextField(
              controller: _mensaje,
              minLines: 2,
              maxLines: 5,
              maxLength: largoMensajeAviso,
              decoration: const InputDecoration(
                labelText: 'Mensaje (opcional)',
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String?>(
              initialValue: _versionId,
              decoration: const InputDecoration(labelText: 'Para'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos los estudiantes'),
                ),
                for (final v in widget.versiones)
                  DropdownMenuItem(
                    value: v.id,
                    child: Text('Solo ${v.nombre}'),
                  ),
              ],
              onChanged: (v) => setState(() => _versionId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Se ve hasta')),
                OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(fechaPanel(_hasta)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Importante'),
              subtitle: const Text('Se destaca y va primero'),
              value: _importante,
              onChanged: (v) => setState(() => _importante = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: !listo
              ? null
              : () => Navigator.pop(
                  context,
                  Aviso(
                    id: widget.aviso?.id ?? '',
                    titulo: _titulo.text.trim(),
                    mensaje: _mensaje.text.trim(),
                    versionId: _versionId,
                    importante: _importante,
                    activo: widget.aviso?.activo ?? true,
                    hasta: _hasta,
                    creadoEn: widget.aviso?.creadoEn,
                  ),
                ),
          child: Text(widget.aviso == null ? 'Publicar' : 'Guardar'),
        ),
      ],
    );
  }
}
