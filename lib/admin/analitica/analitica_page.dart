import 'package:flutter/material.dart';

import '../animacion_panel.dart';
import '../../features/premium/domain/pago.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../estudiantes/repositorio_estudiantes_admin.dart';
import '../estudiantes/vista_estudiante.dart';
import '../graficos.dart';
import '../pagos/repositorio_pagos_admin.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'modelo_analitica.dart';

typedef _Datos = (List<EstudianteAdmin>, List<Pago>, List<ActividadDia>);

/// Cómo va la academia: estudiantes, ingresos, uso y retención.
class AnaliticaPage extends StatefulWidget {
  final RepositorioEstudiantesAdmin estudiantes;
  final RepositorioPagosAdmin pagos;
  final ValueChanged<FiltroEstudiantes> onVerEstudiantes;
  final DateTime Function() ahora;

  const AnaliticaPage({
    super.key,
    required this.estudiantes,
    required this.pagos,
    required this.onVerEstudiantes,
    this.ahora = DateTime.now,
  });

  @override
  State<AnaliticaPage> createState() => _AnaliticaPageState();
}

class _AnaliticaPageState extends State<AnaliticaPage> {
  late Future<_Datos> _datos = _cargar();

  Future<_Datos> _cargar() => (
    widget.estudiantes.estudiantes(),
    widget.pagos.pagos(EstadoPago.aprobado),
    widget.estudiantes.actividadReciente(dias: 30),
  ).wait;

  void _recargar() {
    setState(() {
      _datos = _cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel<_Datos>(
      futuro: _datos,
      onReintentar: _recargar,
      builder: (context, datos) {
        final (estudiantes, pagos, actividad) = datos;
        final p = PaletaPanel.de(context);
        final hoy = widget.ahora();
        final ingresos = ingresosPorMes(pagos, hoy);
        final registros = registrosPorMes(estudiantes, hoy);
        final situaciones = porSituacion(estudiantes, hoy);
        final premium = estudiantes.where((e) => e.esPremiumEn(hoy)).length;
        final conversion = estudiantes.isEmpty
            ? 0
            : (premium * 100 / estudiantes.length).round();
        final volvieron = retencion(estudiantes, hoy);
        final activos = situaciones[SituacionEstudiante.activo]!;

        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Analítica',
              subtitulo:
                  'Cómo va la academia: estudiantes, ingresos y cuánto usan '
                  'la app. Se calcula con los datos de ahora.',
              acciones: [
                OutlinedButton.icon(
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            RejillaPanel(
              anchoMinimo: 230,
              children: [
                IndicadorPanel(
                  etiqueta: 'Estudiantes registrados',
                  valor: '${estudiantes.length}',
                  pildora: '+${registros.last.$2} este mes',
                  colorPildora: p.secundario,
                  tendencia: [for (final (_, n) in registros) n.toDouble()],
                  nota: 'registros por mes',
                  onTap: () => widget.onVerEstudiantes(FiltroEstudiantes.todos),
                ),
                IndicadorPanel(
                  etiqueta: 'Matriculados activos',
                  valor: '$activos',
                  anillo: volvieron,
                  nota: volvieron == null
                      ? 'sin matrículas activas'
                      : '${(volvieron * 100).round()} % entró esta semana',
                  onTap: () =>
                      widget.onVerEstudiantes(FiltroEstudiantes.activos),
                ),
                IndicadorPanel(
                  etiqueta: 'Premium',
                  valor: '$premium',
                  pildora: '$conversion %',
                  colorPildora: p.acento,
                  nota: 'de todos los registrados',
                  onTap: () =>
                      widget.onVerEstudiantes(FiltroEstudiantes.premium),
                ),
                IndicadorPanel(
                  etiqueta: 'Cobrado este mes',
                  valor: 'S/ ${ingresos.last.$2}',
                  pildora: variacion(ingresos),
                  colorPildora: p.secundario,
                  tendencia: [for (final (_, n) in ingresos) n.toDouble()],
                  nota: 'pagos aprobados por mes',
                ),
              ],
            ),
            DosColumnas(
              principal: _tarjetaIngresos(ingresos),
              lateral: TarjetaPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TituloTarjeta('Nuevos estudiantes por mes'),
                    GraficoBarras(
                      etiquetas: [for (final (m, _) in registros) mesBreve(m)],
                      valores: [for (final (_, n) in registros) n],
                      alto: 240,
                    ),
                  ],
                ),
              ),
            ),
            DosColumnas(
              principal: _tarjetaActividad(actividad),
              lateral: _tarjetaRetencion(volvieron, situaciones),
            ),
            _tarjetaCarreras(porCarrera(estudiantes), estudiantes.length),
          ],
        );
      },
    );
  }

  Widget _tarjetaIngresos(List<(DateTime, int)> ingresos) {
    final p = PaletaPanel.de(context);
    final total = ingresos.fold<int>(0, (t, m) => t + m.$2);
    final serie = SerieGrafico(
      nombre: 'Soles cobrados',
      valores: [for (final (_, n) in ingresos) n.toDouble()],
      color: p.acento,
      relleno: true,
    );
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            'Ingresos de los últimos ${ingresos.length} meses',
            extra: Insignia('S/ $total', tono: TonoInsignia.acento),
          ),
          GraficoArea(
            etiquetas: [for (final (m, _) in ingresos) mesBreve(m)],
            series: [serie],
          ),
          const SizedBox(height: 8),
          Text(
            'Solo pagos aprobados (Yape y Plin). Las becas no suman.',
            style: TextStyle(color: p.tenue, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaActividad(List<ActividadDia> actividad) {
    final p = PaletaPanel.de(context);
    final series = [
      SerieGrafico(
        nombre: 'Prácticas',
        valores: [for (final d in actividad) d.practicas.toDouble()],
        color: p.acento,
        relleno: true,
      ),
      SerieGrafico(
        nombre: 'Exámenes semanales',
        valores: [for (final d in actividad) d.simulacros.toDouble()],
        color: p.texto,
      ),
    ];
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta('Uso de los últimos ${actividad.length} días'),
          LeyendaGrafico(series),
          const SizedBox(height: 12),
          GraficoArea(
            etiquetas: [for (final d in actividad) fechaBreve(d.dia)],
            series: series,
          ),
        ],
      ),
    );
  }

  Widget _tarjetaRetencion(
    double? volvieron,
    Map<SituacionEstudiante, int> situaciones,
  ) {
    final p = PaletaPanel.de(context);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloTarjeta('Retención'),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  AnilloAvance(
                    volvieron ?? 0,
                    tamano: 96,
                    grosor: 9,
                    color: p.secundario,
                  ),
                  Text(
                    volvieron == null ? '—' : '${(volvieron * 100).round()} %',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'De los matriculados activos, los que abrieron la app en '
                  'los últimos 7 días.',
                  style: TextStyle(color: p.apagado, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (iFila, s) in SituacionEstudiante.values.indexed)
            FilaEntrante(
              indice: iFila,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    insigniaSituacion(s),
                    const Spacer(),
                    Text(
                      '${situaciones[s]}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaCarreras(List<(String, int)> carreras, int total) {
    final p = PaletaPanel.de(context);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloTarjeta('Carreras a las que postulan'),
          if (carreras.isEmpty)
            Text('Sin datos todavía.', style: TextStyle(color: p.apagado))
          else
            for (final (iFila, (carrera, n)) in carreras.indexed)
              FilaEntrante(
                indice: iFila,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 240,
                        child: Text(
                          carrera,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(child: BarraAvance(n / total)),
                      SizedBox(
                        width: 90,
                        child: Text(
                          '$n · ${(n * 100 / total).round()} %',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: p.apagado),
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
