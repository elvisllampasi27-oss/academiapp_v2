import 'dart:async';

import 'package:flutter/material.dart';

import '../estudiantes/matricular_dialogo.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../estudiantes/repositorio_estudiantes_admin.dart';
import '../../features/premium/domain/pago.dart';
import '../graficos.dart';
import '../pagos/repositorio_pagos_admin.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';

typedef _Datos = (
  List<EstudianteAdmin>,
  List<AccionAdmin>,
  List<ActividadDia>,
  List<Pago>,
);

/// Primera pantalla del panel: cifras del día, lo que requiere atención y
/// las últimas acciones.
class ResumenPage extends StatefulWidget {
  final RepositorioEstudiantesAdmin repositorio;
  final ValueChanged<String> onAbrirEstudiante;
  final ValueChanged<FiltroEstudiantes> onVerEstudiantes;

  /// Pagos por revisar (null en pruebas que no los usan).
  final RepositorioPagosAdmin? pagos;
  final VoidCallback? onVerPagos;
  final String correoAdmin;
  final DateTime Function() ahora;

  const ResumenPage({
    super.key,
    required this.repositorio,
    required this.onAbrirEstudiante,
    required this.onVerEstudiantes,
    this.pagos,
    this.onVerPagos,
    this.correoAdmin = '',
    this.ahora = DateTime.now,
  });

  @override
  State<ResumenPage> createState() => _ResumenPageState();
}

class _ResumenPageState extends State<ResumenPage> {
  late Future<_Datos> _datos = _cargar();
  late DateTime _leido = widget.ahora();

  Future<_Datos> _cargar() {
    _leido = widget.ahora();
    return (
      widget.repositorio.estudiantes(),
      widget.repositorio.accionesRecientes(),
      widget.repositorio.actividadReciente(),
      widget.pagos?.pagos(EstadoPago.pendiente) ?? Future.value(<Pago>[]),
    ).wait;
  }

  void _recargar() => setState(() => _datos = _cargar());

  Future<void> _matricular(List<EstudianteAdmin> estudiantes) async {
    final hecho = await mostrarMatricular(
      context,
      repositorio: widget.repositorio,
      estudiantes: estudiantes,
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
      futuro: _datos,
      onReintentar: _recargar,
      builder: (context, datos) {
        final (estudiantes, acciones, actividad, pendientes) = datos;
        final porCobrar = pendientes.fold(0, (t, x) => t + x.monto);
        final hoy = widget.ahora();
        final r = calcularResumen(estudiantes, hoy);
        final p = PaletaPanel.de(context);
        final matriculados = r.activos + r.programados;
        final porcentajeHoy = matriculados == 0
            ? 0
            : (r.activosHoy * 100 / matriculados).round();
        final nombre = nombreDesdeCorreo(widget.correoAdmin).split(' ').first;
        final hora =
            '${_leido.hour}:${_leido.minute.toString().padLeft(2, '0')}';

        return PaginaPanel(
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TituloDorado(
                          nombre.isEmpty
                              ? saludoPara(hoy)
                              : '${saludoPara(hoy)}, $nombre',
                        ),
                        PildoraEstado(
                          'Datos al día · $hora',
                          color: p.secundario,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fechaPanel(hoy),
                      style: TextStyle(color: p.apagado, fontSize: 14),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _recargar,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Actualizar'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _matricular(estudiantes),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Matricular estudiante'),
                    ),
                  ],
                ),
              ],
            ),
            RejillaPanel(
              anchoMinimo: 230,
              children: [
                IndicadorPanel(
                  etiqueta: 'Matriculados activos',
                  valor: '${r.activos}',
                  pildora: '+${r.nuevasEstaSemana} esta semana',
                  colorPildora: p.secundario,
                  tendencia: [for (final (_, n) in r.porSemana) n.toDouble()],
                  nota: 'matrículas nuevas por semana',
                  onTap: () =>
                      widget.onVerEstudiantes(FiltroEstudiantes.activos),
                ),
                IndicadorPanel(
                  etiqueta: 'Activos hoy',
                  valor: '${r.activosHoy}',
                  pildora: '$porcentajeHoy %',
                  colorPildora: p.acento,
                  tendencia: [
                    for (final d in actividad) d.practicas.toDouble(),
                  ],
                  nota: 'de $matriculados matriculados',
                ),
                IndicadorPanel(
                  etiqueta: 'Sin actividad',
                  valor: '${r.sinActividad.length}',
                  pildora: '$diasSinActividad+ días',
                  colorPildora: r.sinActividad.isEmpty ? null : p.alerta,
                  color: r.sinActividad.isEmpty ? null : p.alerta,
                  nota: 'activos que no abren la app',
                  onTap: () =>
                      widget.onVerEstudiantes(FiltroEstudiantes.sinActividad),
                ),
                IndicadorPanel(
                  etiqueta: 'Pagos por confirmar',
                  valor: '${pendientes.length}',
                  pildora: 'S/ $porCobrar',
                  colorPildora: pendientes.isEmpty ? null : p.acento,
                  color: pendientes.isEmpty ? null : p.acento,
                  nota: '${r.premium} Premium activos',
                  onTap: widget.onVerPagos,
                ),
              ],
            ),
            DosColumnas(
              principal: _graficoActividad(actividad),
              lateral: _GraficoSemanas(porSemana: r.porSemana),
            ),
            DosColumnas(
              flexPrincipal: 3,
              principal: _atencion(r, pendientes),
              lateral: _ultimasAcciones(acciones, hoy),
            ),
          ],
        );
      },
    );
  }

  Widget _graficoActividad(List<ActividadDia> actividad) {
    final p = PaletaPanel.de(context);
    final series = [
      SerieGrafico(
        nombre: 'Prácticas',
        valores: [for (final d in actividad) d.practicas.toDouble()],
        color: p.acento,
        relleno: true,
      ),
      SerieGrafico(
        nombre: 'Exámenes tipo admisión',
        valores: [for (final d in actividad) d.simulacros.toDouble()],
        color: p.texto,
      ),
    ];
    final total = actividad.fold(0, (t, d) => t + d.practicas);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta('Actividad de los últimos ${actividad.length} días'),
          LeyendaGrafico(series),
          const SizedBox(height: 12),
          GraficoArea(
            etiquetas: [for (final d in actividad) fechaBreve(d.dia)],
            series: series,
          ),
          const SizedBox(height: 8),
          Text(
            '$total prácticas resueltas en el periodo. Pasa el mouse sobre el '
            'gráfico para ver cada día.',
            style: TextStyle(color: p.tenue, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _atencion(ResumenPanel r, List<Pago> pendientes) {
    final p = PaletaPanel.de(context);
    final items = [
      if (pendientes.isNotEmpty)
        (
          Icons.receipt_long_outlined,
          p.acento,
          '${pendientes.length} pagos por confirmar',
          'El más antiguo: ${pendientes.last.nombre}, '
              '${haceCuanto(pendientes.last.creadoEn, widget.ahora()).toLowerCase()}',
          'Revisar',
          widget.onVerPagos ?? () {},
        ),
      if (r.premiumPorVencer.isNotEmpty)
        (
          Icons.workspace_premium_outlined,
          p.secundario,
          '${r.premiumPorVencer.length} Premium vencen en 7 días',
          r.premiumPorVencer.take(3).map((e) => e.nombre).join(', '),
          'Ver',
          () => widget.onVerEstudiantes(FiltroEstudiantes.premium),
        ),
      if (r.sinMatricula > 0)
        (
          Icons.how_to_reg_outlined,
          p.acento,
          '${r.sinMatricula} con cuenta y sin matrícula',
          'Se registraron en la app; matricúlalos cuando paguen.',
          'Ver lista',
          () => widget.onVerEstudiantes(FiltroEstudiantes.sinMatricula),
        ),
      if (r.sinActividad.isNotEmpty)
        (
          Icons.schedule,
          p.alerta,
          '${r.sinActividad.length} sin actividad hace $diasSinActividad '
              'días o más',
          r.sinActividad.take(3).map((e) => e.nombre).join(', '),
          'Ver lista',
          () => widget.onVerEstudiantes(FiltroEstudiantes.sinActividad),
        ),
      if (r.programados > 0)
        (
          Icons.event_outlined,
          p.secundario,
          '${r.programados} empiezan en los próximos días',
          'Ya están matriculados; su día 1 aún no llega.',
          'Ver',
          () => widget.onVerEstudiantes(FiltroEstudiantes.programados),
        ),
    ];

    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloTarjeta('Requiere tu atención'),
          if (items.isEmpty)
            Text('Todo en orden.', style: TextStyle(color: p.apagado)),
          for (final (icono, color, titulo, detalle, boton, accion) in items)
            InkWell(
              onTap: accion,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: PaletaPanel.linea)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: PaletaPanel.linea,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icono, size: 18, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            detalle,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.apagado, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      boton,
                      style: TextStyle(
                        color: p.apagado,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: p.tenue),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ultimasAcciones(List<AccionAdmin> acciones, DateTime hoy) {
    final p = PaletaPanel.de(context);
    IconData icono(String tipo) => switch (tipo) {
      'matricula' => Icons.how_to_reg_outlined,
      'inicio' => Icons.event_outlined,
      'estado' => Icons.pause_circle_outline,
      _ => Icons.bolt_outlined,
    };

    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloTarjeta('Últimas acciones en el panel'),
          if (acciones.isEmpty)
            Text(
              'Aquí aparecerá cada matrícula y cambio que hagas.',
              style: TextStyle(color: p.apagado),
            ),
          for (final (k, a) in acciones.indexed)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: a.usuarioId == null
                  ? null
                  : () => widget.onAbrirEstudiante(a.usuarioId!),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          haceCuanto(a.fecha, hoy),
                          style: TextStyle(color: p.tenue, fontSize: 11),
                        ),
                      ),
                    ),
                    // Línea de tiempo: punto con ícono y trazo hacia abajo.
                    Column(
                      children: [
                        const SizedBox(height: 6),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: p.acento.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icono(a.tipo), size: 14, color: p.acento),
                        ),
                        if (k < acciones.length - 1)
                          Expanded(
                            child: Container(
                              width: 1,
                              color: PaletaPanel.borde,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.descripcion),
                            Text(
                              a.adminCorreo,
                              style: TextStyle(color: p.tenue, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GraficoSemanas extends StatelessWidget {
  final List<(DateTime, int)> porSemana;

  const _GraficoSemanas({required this.porSemana});

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final maximo = porSemana.fold(1, (m, s) => s.$2 > m ? s.$2 : m);

    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloTarjeta('Matrículas por semana'),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, (lunes, cantidad)) in porSemana.indexed)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$cantidad',
                          style: TextStyle(color: p.apagado, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        // La barra usa el alto que queda: nunca se desborda.
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: cantidad == 0
                                  ? 0.03
                                  : cantidad / maximo,
                              child: Container(
                                width: 36,
                                decoration: BoxDecoration(
                                  color: i == porSemana.length - 1
                                      ? p.acento
                                      : PaletaPanel.bordeFuerte,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                    bottom: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          fechaBreve(lunes),
                          style: TextStyle(color: p.apagado, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semana de lunes a domingo; la resaltada es la actual.',
            style: TextStyle(color: p.tenue, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
