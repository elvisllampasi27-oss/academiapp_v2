import 'package:flutter/material.dart';

import '../../features/enrollment/domain/entities/matricula.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'matricular_dialogo.dart';
import 'modelo_estudiantes.dart';
import 'repositorio_estudiantes_admin.dart';
import 'vista_estudiante.dart';
import '../../features/premium/domain/pago.dart';
import '../pagos/repositorio_pagos_admin.dart';

/// Seguimiento de un estudiante: matrícula, avance, dominio y lo que se
/// hizo con él desde el panel.
class FichaEstudiantePage extends StatefulWidget {
  final String uid;
  final RepositorioEstudiantesAdmin repositorio;
  final VoidCallback onVolver;

  /// Plan y pagos del estudiante (null en pruebas que no los necesitan).
  final RepositorioPagosAdmin? pagos;
  final DateTime Function() ahora;

  const FichaEstudiantePage({
    super.key,
    required this.uid,
    required this.repositorio,
    required this.onVolver,
    this.pagos,
    this.ahora = DateTime.now,
  });

  @override
  State<FichaEstudiantePage> createState() => _FichaEstudiantePageState();
}

class _FichaEstudiantePageState extends State<FichaEstudiantePage> {
  late Future<FichaEstudiante> _ficha = widget.repositorio.ficha(widget.uid);
  late Future<List<Pago>>? _pagos = widget.pagos?.pagosDe(widget.uid);
  bool _ocupado = false;

  void _recargar() => setState(() {
    _ficha = widget.repositorio.ficha(widget.uid);
    _pagos = widget.pagos?.pagosDe(widget.uid);
  });

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

  Future<void> _cambiarInicio(EstudianteAdmin e, Matricula m) async {
    final inicio = await elegirInicio(
      context,
      inicial: m.fechaInicioAcademico,
      desde: widget.ahora(),
    );
    if (inicio == null) return;
    await _hacer(
      () => widget.repositorio.cambiarInicio(
        estudiante: e,
        matricula: m,
        inicio: inicio,
      ),
      'Fecha de inicio cambiada.',
    );
  }

  Future<void> _cambiarEstado(
    EstudianteAdmin e,
    Matricula m,
    EstadoMatricula estado,
  ) async {
    final suspender = estado == EstadoMatricula.suspendida;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspender ? 'Suspender matrícula' : 'Reactivar matrícula'),
        content: Text(
          suspender
              ? '${e.nombre} dejará de ver sus clases y prácticas hasta que '
                    'la reactives. No se borra nada.'
              : '${e.nombre} vuelve a ver sus clases desde el día en que va.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(suspender ? 'Suspender' : 'Reactivar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _hacer(
      () => widget.repositorio.cambiarEstado(
        estudiante: e,
        matricula: m,
        estado: estado,
      ),
      suspender ? 'Matrícula suspendida.' : 'Matrícula reactivada.',
    );
  }

  Future<void> _darPremium(EstudianteAdmin e) async {
    final repositorio = widget.pagos;
    if (repositorio == null) return;
    final eleccion = await showDialog<(int, String)>(
      context: context,
      builder: (_) => const _DialogoPremium(),
    );
    if (eleccion == null) return;
    final (dias, motivo) = eleccion;
    await _hacer(
      () => repositorio.darPremium(
        uid: e.uid,
        nombre: e.nombre,
        correo: e.correo,
        dias: dias,
        motivo: motivo,
      ),
      'Premium actualizado.',
    );
  }

  Future<void> _matricular(EstudianteAdmin e) async {
    final hecho = await mostrarMatricular(
      context,
      repositorio: widget.repositorio,
      estudiantes: [e],
      estudiante: e,
      ahora: widget.ahora,
    );
    if (hecho && mounted) {
      avisarPanel(context, 'Estudiante matriculado.');
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel(
      futuro: _ficha,
      onReintentar: _recargar,
      builder: (context, f) => _contenido(f),
    );
  }

  Widget _contenido(FichaEstudiante f) {
    final p = PaletaPanel.de(context);
    final e = f.estudiante;
    final m = e.matricula;
    final hoy = widget.ahora();
    final s = situacion(e, hoy);

    final acciones = <Widget>[
      if (m == null || s == SituacionEstudiante.finalizado)
        FilledButton.icon(
          onPressed: _ocupado ? null : () => _matricular(e),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Matricular'),
        ),
      if (m != null && s != SituacionEstudiante.finalizado) ...[
        OutlinedButton.icon(
          onPressed: _ocupado ? null : () => _cambiarInicio(e, m),
          icon: const Icon(Icons.event_outlined, size: 18),
          label: const Text('Cambiar fecha de inicio'),
        ),
        if (s == SituacionEstudiante.suspendido)
          FilledButton.icon(
            onPressed: _ocupado
                ? null
                : () => _cambiarEstado(e, m, EstadoMatricula.activa),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Reactivar matrícula'),
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: p.alerta,
              side: BorderSide(color: p.alerta.withValues(alpha: 0.45)),
            ),
            onPressed: _ocupado
                ? null
                : () => _cambiarEstado(e, m, EstadoMatricula.suspendida),
            icon: const Icon(Icons.pause, size: 18),
            label: const Text('Suspender matrícula'),
          ),
      ],
    ];

    final dia = m == null ? 0 : diaAcademico(m.fechaInicioAcademico, hoy);
    final aciertos = f.respuestas == 0 ? null : f.correctas / f.respuestas;
    final ultimo = f.simulacros.firstOrNull;

    return PaginaPanel(
      children: [
        EncabezadoPanel(
          migas: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: widget.onVolver,
                child: Text('Estudiantes', style: TextStyle(color: p.apagado)),
              ),
              Icon(Icons.chevron_right, size: 16, color: p.tenue),
              Text(e.nombre),
            ],
          ),
          titulo: e.nombre,
          subtitulo: [e.correo, ?e.carrera].join(' · '),
          acciones: acciones,
        ),
        RejillaPanel(
          children: [
            IndicadorPanel(
              etiqueta: 'Día académico',
              valor: m == null ? '—' : '$dia',
              nota: switch (f.fin) {
                final fin? =>
                  'de ${fin.dias} · termina ${fechaBreve(fin.fecha)}',
                null => null,
              },
            ),
            IndicadorPanel(
              etiqueta: 'Clases vistas completas',
              valor: '${f.clasesCompletas}',
              nota: f.totalTemas == 0 ? null : 'de ${f.totalTemas} temas',
            ),
            IndicadorPanel(
              etiqueta: 'Aciertos en prácticas',
              valor: aciertos == null ? '—' : '${(aciertos * 100).round()} %',
              nota: '${f.respuestas} respuestas',
              color: aciertos == null
                  ? null
                  : aciertos >= 0.6
                  ? p.secundario
                  : p.alerta,
            ),
            IndicadorPanel(
              etiqueta: 'Exámenes tipo admisión',
              valor: '${f.simulacros.length}',
              nota: ultimo == null
                  ? 'aún no rinde'
                  : 'último: ${ultimo.correctas} de ${ultimo.total}',
            ),
          ],
        ),
        DosColumnas(
          flexPrincipal: 1,
          principal: ColumnaPanel(
            children: [
              _matricula(f, s),
              if (widget.pagos != null) _plan(e, hoy),
              TarjetaPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TituloTarjeta('Cuenta'),
                    FilaDato(
                      'Registrado',
                      e.registro == null ? '—' : fechaPanel(e.registro!),
                    ),
                    FilaDato(
                      'Última actividad',
                      haceCuanto(e.ultimaActividad, hoy),
                    ),
                  ],
                ),
              ),
              if (f.matriculas.length > 1) _historial(f),
            ],
          ),
          lateral: ColumnaPanel(
            children: [_dominio(f), _simulacros(f), _acciones(f, hoy)],
          ),
        ),
      ],
    );
  }

  Widget _matricula(FichaEstudiante f, SituacionEstudiante s) {
    final m = f.estudiante.matricula;
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta('Matrícula', extra: insigniaSituacion(s)),
          if (m == null)
            Text(
              'Tiene cuenta pero no está matriculado.',
              style: TextStyle(color: PaletaPanel.de(context).apagado),
            )
          else ...[
            FilaDato('Versión', f.version?.nombre ?? m.versionId),
            FilaDato('Fecha de matrícula', fechaPanel(m.fechaMatricula)),
            FilaDato('Inicio académico', fechaPanel(m.fechaInicioAcademico)),
            if (f.fin case final fin?)
              FilaDato('Fin estimado', fechaPanel(fin.fecha)),
          ],
        ],
      ),
    );
  }

  Widget _plan(EstudianteAdmin e, DateTime hoy) {
    final p = PaletaPanel.de(context);
    final premium = e.esPremiumEn(hoy);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            'Plan',
            extra: premium
                ? const Insignia('Premium', tono: TonoInsignia.acento)
                : const Insignia('Gratis'),
          ),
          if (premium) FilaDato('Vence', fechaPanel(e.premiumHasta!)),
          FutureBuilder<List<Pago>>(
            future: _pagos,
            builder: (context, s) {
              final pagos = s.data;
              if (pagos == null) return const SizedBox(height: 8);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final pago in pagos.take(6))
                    FilaDato(
                      '${fechaBreve(pago.creadoEn)} · '
                      '${pago.metodo == MetodoPago.yape || pago.metodo == MetodoPago.plin ? 'S/ ${pago.monto} ${pago.metodo.etiqueta}' : pago.metodo.etiqueta}',
                      switch (pago.estado) {
                        EstadoPago.pendiente => 'Por revisar',
                        EstadoPago.aprobado => 'Aprobado',
                        EstadoPago.rechazado => 'Rechazado',
                      },
                    ),
                  if (pagos.isEmpty)
                    Text('Sin pagos.', style: TextStyle(color: p.apagado)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _ocupado ? null : () => _darPremium(e),
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            label: Text(premium ? 'Extender Premium' : 'Dar Premium'),
          ),
        ],
      ),
    );
  }

  Widget _historial(FichaEstudiante f) {
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloTarjeta('Matrículas anteriores'),
          for (final m in f.matriculas.where(
            (m) => m.id != f.estudiante.matricula?.id,
          ))
            FilaDato(
              '${m.versionId} · ${fechaBreve(m.fechaMatricula)}',
              m.estado.name,
            ),
        ],
      ),
    );
  }

  Widget _dominio(FichaEstudiante f) {
    final p = PaletaPanel.de(context);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            'Dominio por curso',
            extra: Text(
              'según sus respuestas (BKT)',
              style: TextStyle(color: p.tenue, fontSize: 12),
            ),
          ),
          if (f.dominio.isEmpty)
            Text(
              'Aún no resuelve prácticas.',
              style: TextStyle(color: p.apagado),
            ),
          for (final d in f.dominio)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 170, child: Text(d.curso)),
                  Expanded(
                    child: BarraAvance(
                      d.valor,
                      color: d.valor >= 0.6 ? p.secundario : p.alerta,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${(d.valor * 100).round()} %',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: p.apagado, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (f.reforzar.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'PARA REFORZAR',
              style: TextStyle(
                color: p.tenue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            for (final t in f.reforzar)
              FilaDato(t.tema, '${(t.valor * 100).round()} %'),
          ],
        ],
      ),
    );
  }

  Widget _simulacros(FichaEstudiante f) {
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloTarjeta('Exámenes tipo admisión'),
          if (f.simulacros.isEmpty)
            Text(
              'Aún no rinde ninguno.',
              style: TextStyle(color: PaletaPanel.de(context).apagado),
            ),
          for (final r in f.simulacros.take(6))
            FilaDato(
              fechaPanel(r.fecha),
              '${r.correctas} de ${r.total} · '
              '${r.segundos ~/ 60}:${(r.segundos % 60).toString().padLeft(2, '0')}',
            ),
        ],
      ),
    );
  }

  Widget _acciones(FichaEstudiante f, DateTime hoy) {
    final p = PaletaPanel.de(context);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloTarjeta('Historial en el panel'),
          if (f.acciones.isEmpty)
            Text('Sin cambios todavía.', style: TextStyle(color: p.apagado)),
          for (final a in f.acciones.take(15))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.descripcion),
                  Text(
                    '${haceCuanto(a.fecha, hoy)} · ${a.adminCorreo}',
                    style: TextStyle(color: p.tenue, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Días de Premium y el motivo (cortesía, compensación…).
class _DialogoPremium extends StatefulWidget {
  const _DialogoPremium();

  @override
  State<_DialogoPremium> createState() => _DialogoPremiumState();
}

class _DialogoPremiumState extends State<_DialogoPremium> {
  final _motivo = TextEditingController();
  int _dias = 90;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dar o extender Premium'),
      content: SizedBox(
        width: 420,
        child: ColumnaPanel(
          espacio: 14,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final d in const [7, 30, 90])
                  ChoiceChip(
                    label: Text('$d días'),
                    selected: _dias == d,
                    onSelected: (_) => setState(() => _dias = d),
                  ),
              ],
            ),
            TextField(
              controller: _motivo,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Pagó en efectivo, cortesía, compensación…',
              ),
            ),
            Text(
              'Si ya es Premium, los días se suman a los que le quedan.',
              style: TextStyle(
                color: PaletaPanel.de(context).tenue,
                fontSize: 12,
              ),
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
          onPressed: _motivo.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (_dias, _motivo.text.trim())),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
