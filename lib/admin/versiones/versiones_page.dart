import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/academic/domain/entities/curriculo.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../estudiantes/repositorio_estudiantes_admin.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'modelo_versiones.dart';
import 'nueva_version.dart';
import 'repositorio_versiones_admin.dart';

typedef _Datos = (List<VersionAcademica>, List<EstudianteAdmin>);

/// Versiones (ciclos): estado, fechas de matrícula, publicación de temas
/// día por día y cuándo empezó cada estudiante.
class VersionesPage extends StatefulWidget {
  final RepositorioVersionesAdmin versiones;
  final RepositorioEstudiantesAdmin estudiantes;
  final VoidCallback onVerEstudiantes;
  final DateTime Function() ahora;

  const VersionesPage({
    super.key,
    required this.versiones,
    required this.estudiantes,
    required this.onVerEstudiantes,
    this.ahora = DateTime.now,
  });

  @override
  State<VersionesPage> createState() => _VersionesPageState();
}

class _VersionesPageState extends State<VersionesPage> {
  late Future<_Datos> _datos = _cargar();
  String? _elegidaId;
  bool _creando = false;
  bool _verArchivadas = false;

  Future<_Datos> _cargar() =>
      (widget.estudiantes.versiones(), widget.estudiantes.estudiantes()).wait;

  void _recargar() => setState(() {
    _datos = _cargar();
  });

  @override
  Widget build(BuildContext context) {
    return FuturoPanel(
      futuro: _datos,
      onReintentar: _recargar,
      builder: (context, datos) {
        final (todas, estudiantes) = datos;
        if (_creando) {
          return NuevaVersionPage(
            repositorio: widget.versiones,
            versiones: todas,
            ahora: widget.ahora,
            onCancelar: () => setState(() => _creando = false),
            onCreada: (id) => setState(() {
              _creando = false;
              _elegidaId = id;
              _datos = _cargar();
            }),
          );
        }

        final hoy = widget.ahora();
        final visibles = todas
            .where(
              (v) =>
                  _verArchivadas ||
                  v.estado != EstadoVersionAcademica.archivada,
            )
            .toList();
        final elegida =
            visibles.where((v) => v.id == _elegidaId).firstOrNull ??
            visibles.firstOrNull;

        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Versiones y matrículas',
              subtitulo:
                  'Cada versión es un ciclo con su temario, su calendario y '
                  'sus fechas de matrícula.',
              acciones: [
                OutlinedButton.icon(
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                ),
                FilledButton.icon(
                  onPressed: todas.isEmpty
                      ? null
                      : () => setState(() => _creando = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva versión'),
                ),
              ],
            ),
            if (elegida == null)
              TarjetaPanel(
                child: Text(
                  'No hay versiones.',
                  style: TextStyle(color: PaletaPanel.de(context).apagado),
                ),
              )
            else
              DosColumnas(
                flexPrincipal: 1,
                flexLateral: 3,
                principal: ColumnaPanel(
                  espacio: 10,
                  children: [
                    for (final v in visibles)
                      _TarjetaVersion(
                        version: v,
                        conteo: contarVersion(v.id, estudiantes, hoy),
                        elegida: v.id == elegida.id,
                        onTap: () => setState(() => _elegidaId = v.id),
                      ),
                    if (todas.length != visibles.length || _verArchivadas)
                      TextButton(
                        onPressed: () =>
                            setState(() => _verArchivadas = !_verArchivadas),
                        child: Text(
                          _verArchivadas
                              ? 'Ocultar archivadas'
                              : 'Ver archivadas',
                        ),
                      ),
                  ],
                ),
                lateral: _DetalleVersion(
                  key: ValueKey(elegida.id),
                  version: elegida,
                  estudiantes: estudiantes,
                  repositorio: widget.versiones,
                  temario: widget.estudiantes.curriculo(elegida.id),
                  hoy: hoy,
                  onCambio: _recargar,
                  onVerEstudiantes: widget.onVerEstudiantes,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TarjetaVersion extends StatelessWidget {
  final VersionAcademica version;
  final ConteoVersion conteo;
  final bool elegida;
  final VoidCallback onTap;

  const _TarjetaVersion({
    required this.version,
    required this.conteo,
    required this.elegida,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final v = version;
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      v.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _insigniaEstado(v.estado),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Abre ${fechaBreve(v.fechaApertura)}'
                '${v.fechaCorte == null ? '' : ' · matrículas hasta ${fechaBreve(v.fechaCorte!)}'}',
                style: TextStyle(color: p.apagado, fontSize: 13),
              ),
              Text(
                '${conteo.total} matriculados · ${v.codigo}',
                style: TextStyle(color: p.apagado, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Insignia _insigniaEstado(EstadoVersionAcademica e) => Insignia(
  e == EstadoVersionAcademica.cerradaNuevasMatriculas ? 'Cerrada' : e.etiqueta,
  tono: switch (e) {
    EstadoVersionAcademica.activa => TonoInsignia.secundario,
    EstadoVersionAcademica.preparacion ||
    EstadoVersionAcademica.publicada => TonoInsignia.acento,
    EstadoVersionAcademica.cerradaNuevasMatriculas => TonoInsignia.alerta,
    _ => TonoInsignia.gris,
  },
);

class _DetalleVersion extends StatefulWidget {
  final VersionAcademica version;
  final List<EstudianteAdmin> estudiantes;
  final RepositorioVersionesAdmin repositorio;
  final Future<Curriculo> temario;
  final DateTime hoy;
  final VoidCallback onCambio;
  final VoidCallback onVerEstudiantes;

  const _DetalleVersion({
    super.key,
    required this.version,
    required this.estudiantes,
    required this.repositorio,
    required this.temario,
    required this.hoy,
    required this.onCambio,
    required this.onVerEstudiantes,
  });

  @override
  State<_DetalleVersion> createState() => _DetalleVersionState();
}

class _DetalleVersionState extends State<_DetalleVersion> {
  late Future<(Curriculo?, Set<String>)> _temario = _cargarTemario();
  int? _hasta;
  bool _ocupado = false;

  Future<(Curriculo?, Set<String>)> _cargarTemario() async {
    Curriculo? curriculo;
    try {
      curriculo = await widget.temario;
    } catch (_) {
      curriculo = null; // sin temario cargado
    }
    return (curriculo, await widget.repositorio.publicados(widget.version.id));
  }

  Future<void> _hacer(Future<void> Function() accion, String hecho) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (!mounted) return;
      avisarPanel(context, hecho);
      widget.onCambio();
    } catch (e) {
      if (mounted) {
        avisarPanel(context, e is StateError ? e.message : 'No se pudo: $e');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cambiarEstado(EstadoVersionAcademica nuevo) async {
    final v = widget.version;
    if (nuevo == v.estado) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Pasar a "${nuevo.etiqueta}"?'),
        content: Text(nuevo.explicacion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _hacer(
      () => widget.repositorio.guardar(
        VersionAcademica(
          id: v.id,
          codigo: v.codigo,
          nombre: v.nombre,
          fechaApertura: v.fechaApertura,
          fechaCorte: v.fechaCorte,
          estado: nuevo,
        ),
        cambio: 'pasó de "${v.estado.etiqueta}" a "${nuevo.etiqueta}"',
      ),
      'Estado cambiado.',
    );
  }

  Future<void> _editar() async {
    final editada = await showDialog<VersionAcademica>(
      context: context,
      builder: (_) => DialogoDatosVersion(version: widget.version),
    );
    if (editada == null) return;
    await _hacer(
      () => widget.repositorio.guardar(
        editada,
        cambio:
            'datos editados (abre ${fechaPanel(editada.fechaApertura)}'
            '${editada.fechaCorte == null ? '' : ', matrículas hasta ${fechaPanel(editada.fechaCorte!)}'})',
      ),
      'Versión guardada.',
    );
  }

  Future<void> _publicar(List<DiaVersion> dias, Set<String> ya, int hasta) {
    final temas = temasPorPublicar(dias, hasta, ya);
    return _hacer(() async {
      await widget.repositorio.publicar(
        widget.version.id,
        temas: temas,
        dia: hasta,
      );
      if (mounted) {
        setState(() {
          _hasta = null;
          _temario = _cargarTemario();
        });
      }
    }, 'Publicados ${temas.length} temas hasta el día $hasta.');
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.version;
    final conteo = contarVersion(v.id, widget.estudiantes, widget.hoy);

    return FutureBuilder<(Curriculo?, Set<String>)>(
      future: _temario,
      builder: (context, s) {
        final (curriculo, publicados) = s.data ?? (null, const <String>{});
        final inicio =
            inicioMasAdelantado(v.id, widget.estudiantes) ?? v.fechaApertura;
        final dias = curriculo == null
            ? const <DiaVersion>[]
            : calendarioVersion(curriculo, inicio);
        final cursos = curriculo?.cursos.where((c) => c.activo).length ?? 0;

        return ColumnaPanel(
          children: [
            TarjetaPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TituloTarjeta(
                    v.nombre,
                    extra: OutlinedButton.icon(
                      onPressed: _ocupado ? null : _editar,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar datos'),
                    ),
                  ),
                  _PasosEstado(
                    actual: v.estado,
                    onElegir: _ocupado ? null : _cambiarEstado,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    v.estado.explicacion,
                    style: TextStyle(color: PaletaPanel.de(context).apagado),
                  ),
                  const SizedBox(height: 16),
                  RejillaPanel(
                    anchoMinimo: 170,
                    children: [
                      IndicadorPanel(
                        etiqueta: 'Matriculados',
                        valor: '${conteo.total}',
                        nota:
                            '${conteo.activos} activos · ${conteo.programados} '
                            'por empezar · ${conteo.suspendidos} suspendidos',
                        onTap: widget.onVerEstudiantes,
                      ),
                      IndicadorPanel(
                        etiqueta: 'Temario',
                        valor: curriculo == null
                            ? '—'
                            : '${dias.fold<int>(0, (t, d) => t + d.temas.length)} temas',
                        nota: curriculo == null
                            ? 'sin temario cargado'
                            : '$cursos cursos · ${dias.length} días · '
                                  'publicado hasta el ${ultimoDiaPublicado(dias, publicados)}',
                        anillo: dias.isEmpty
                            ? null
                            : ultimoDiaPublicado(dias, publicados) /
                                  dias.length,
                      ),
                      IndicadorPanel(
                        etiqueta: 'Apertura',
                        valor: fechaBreve(v.fechaApertura),
                        nota: '${v.fechaApertura.year}',
                      ),
                      IndicadorPanel(
                        etiqueta: 'Matrículas hasta',
                        valor: v.fechaCorte == null
                            ? 'Abierta'
                            : fechaBreve(v.fechaCorte!),
                        nota: v.fechaCorte == null
                            ? 'sin fecha de cierre'
                            : '${v.fechaCorte!.year}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (s.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else if (curriculo == null || dias.isEmpty)
              TarjetaPanel(
                child: Text(
                  'Esta versión no tiene temario (curriculos/${v.id}).',
                  style: TextStyle(color: PaletaPanel.de(context).alerta),
                ),
              )
            else
              _calendario(dias, publicados, inicio),
            _inicios(),
          ],
        );
      },
    );
  }

  Widget _calendario(
    List<DiaVersion> dias,
    Set<String> publicados,
    DateTime inicio,
  ) {
    final p = PaletaPanel.de(context);
    final hayMatriculados =
        inicioMasAdelantado(widget.version.id, widget.estudiantes) != null;
    final diaActual = hayMatriculados ? diaAcademico(inicio, widget.hoy) : 0;
    final ultimo = ultimoDiaPublicado(dias, publicados);
    final sugerido = (diaActual + 2).clamp(1, dias.length).toInt();
    final hasta = _hasta ?? (sugerido > ultimo ? sugerido : ultimo + 1);
    final hastaValido = hasta.clamp(1, dias.length).toInt();
    final faltan = temasPorPublicar(dias, hastaValido, publicados);
    final atrasados = dias
        .where((d) => estadoDia(d, diaActual, publicados) == EstadoDia.atrasado)
        .length;

    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            'Calendario y publicación',
            extra: FilledButton.icon(
              onPressed: _ocupado || faltan.isEmpty
                  ? null
                  : () => _publicar(dias, publicados, hastaValido),
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                faltan.isEmpty
                    ? 'Publicado hasta el día $ultimo'
                    : 'Publicar hasta el día $hastaValido',
              ),
            ),
          ),
          Text(
            hayMatriculados
                ? 'Lunes a viernes 3 temas, sábado 2, domingo libre. El más '
                      'adelantado empezó el ${fechaPanel(inicio)} y hoy va en '
                      'el día $diaActual; conviene publicar 2 días por '
                      'delante. Toca un día para elegir hasta dónde publicar.'
                : 'Todavía no hay estudiantes activos: el calendario cuenta '
                      'desde la apertura. Toca un día para elegir hasta dónde '
                      'publicar.',
            style: TextStyle(color: p.apagado, height: 1.45),
          ),
          if (atrasados > 0) ...[
            const SizedBox(height: 10),
            Text(
              '$atrasados días ya alcanzados no están publicados: el '
              'estudiante no ve sus temas.',
              style: TextStyle(color: p.alerta, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in dias)
                _DiaCalendario(
                  dia: d,
                  estado: estadoDia(d, diaActual, publicados),
                  elegido: d.numero <= hastaValido && d.numero > ultimo,
                  onTap: () => setState(() => _hasta = d.numero),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _leyenda(p.texto, 'Ya llegó el más adelantado'),
              _leyenda(
                p.acento.withValues(alpha: 0.5),
                'Publicado por adelantado',
              ),
              _leyenda(PaletaPanel.bordeFuerte, 'Sin publicar'),
              _leyenda(p.alerta, 'Alcanzado sin publicar'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        texto,
        style: TextStyle(color: PaletaPanel.de(context).apagado, fontSize: 12),
      ),
    ],
  );

  Widget _inicios() {
    final p = PaletaPanel.de(context);
    final grupos = iniciosPorFecha(widget.version.id, widget.estudiantes);
    final total = grupos.fold<int>(0, (t, g) => t + g.$2);
    final principales = grupos.take(4).toList();
    final otros = total - principales.fold<int>(0, (t, g) => t + g.$2);

    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            'Inicio de los estudiantes',
            extra: TextButton(
              onPressed: widget.onVerEstudiantes,
              child: const Text('Ver estudiantes'),
            ),
          ),
          if (total == 0)
            Text(
              'Nadie matriculado todavía.',
              style: TextStyle(color: p.apagado),
            ),
          for (final (fecha, n) in principales)
            _barra(
              '${fecha.isAfter(widget.hoy) ? 'Inicia' : 'Inició'} '
              '${fechaBreve(fecha)}',
              n,
              total,
            ),
          if (otros > 0) _barra('Otras fechas', otros, total),
        ],
      ),
    );
  }

  Widget _barra(String etiqueta, int n, int total) {
    final p = PaletaPanel.de(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(etiqueta, style: TextStyle(color: p.apagado)),
          ),
          Expanded(child: BarraAvance(n / total, color: p.acento, alto: 8)),
          SizedBox(
            width: 120,
            child: Text(
              '$n ${n == 1 ? 'estudiante' : 'estudiantes'}',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Los 6 estados de una versión como pasos; se toca uno para cambiar.
class _PasosEstado extends StatelessWidget {
  final EstadoVersionAcademica actual;
  final ValueChanged<EstadoVersionAcademica>? onElegir;

  const _PasosEstado({required this.actual, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final indice = EstadoVersionAcademica.values.indexOf(actual);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, e) in EstadoVersionAcademica.values.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onElegir == null ? null : () => onElegir!(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == indice
                            ? p.acento
                            : i < indice
                            ? p.texto.withValues(alpha: 0.45)
                            : PaletaPanel.borde,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.etiqueta,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12,
                        color: i == indice ? p.texto : p.apagado,
                        fontWeight: i == indice
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DiaCalendario extends StatelessWidget {
  final DiaVersion dia;
  final EstadoDia estado;
  final bool elegido;
  final VoidCallback onTap;

  const _DiaCalendario({
    required this.dia,
    required this.estado,
    required this.elegido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final (fondo, texto, borde) = switch (estado) {
      EstadoDia.alcanzado => (p.texto, p.fondo, p.texto),
      EstadoDia.adelantado => (
        p.acento.withValues(alpha: 0.22),
        p.acento,
        p.acento.withValues(alpha: 0.5),
      ),
      EstadoDia.atrasado => (
        p.alerta.withValues(alpha: 0.18),
        p.alerta,
        p.alerta,
      ),
      EstadoDia.pendiente => (
        elegido ? p.acento.withValues(alpha: 0.10) : PaletaPanel.panel,
        elegido ? p.acento : p.apagado,
        elegido ? p.acento : PaletaPanel.borde,
      ),
    };
    return Tooltip(
      message:
          'Día ${dia.numero} · ${fechaPanel(dia.fecha)} · ${dia.temas.length} temas',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 38,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borde,
              width: elegido && estado == EstadoDia.pendiente ? 1.6 : 1,
            ),
          ),
          child: Text(
            '${dia.numero}',
            style: TextStyle(
              color: texto,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
