import 'dart:async';

import 'package:flutter/material.dart';

import '../estudiantes/matricular_dialogo.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../estudiantes/repositorio_estudiantes_admin.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';

/// Primera pantalla del panel: cifras del día, lo que requiere atención y
/// las últimas acciones.
class ResumenPage extends StatefulWidget {
  final RepositorioEstudiantesAdmin repositorio;
  final ValueChanged<String> onAbrirEstudiante;
  final ValueChanged<FiltroEstudiantes> onVerEstudiantes;
  final DateTime Function() ahora;

  const ResumenPage({
    super.key,
    required this.repositorio,
    required this.onAbrirEstudiante,
    required this.onVerEstudiantes,
    this.ahora = DateTime.now,
  });

  @override
  State<ResumenPage> createState() => _ResumenPageState();
}

class _ResumenPageState extends State<ResumenPage> {
  late Future<(List<EstudianteAdmin>, List<AccionAdmin>)> _datos = _cargar();

  Future<(List<EstudianteAdmin>, List<AccionAdmin>)> _cargar() => (
    widget.repositorio.estudiantes(),
    widget.repositorio.accionesRecientes(),
  ).wait;

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
        final (estudiantes, acciones) = datos;
        final hoy = widget.ahora();
        final r = calcularResumen(estudiantes, hoy);
        final p = PaletaPanel.de(context);
        final matriculados = r.activos + r.programados;

        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Resumen',
              subtitulo: fechaPanel(hoy),
              acciones: [
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
            RejillaPanel(
              anchoMinimo: 190,
              children: [
                IndicadorPanel(
                  etiqueta: 'Matriculados activos',
                  valor: '${r.activos}',
                  nota: '+${r.nuevasEstaSemana} esta semana',
                  onTap: () =>
                      widget.onVerEstudiantes(FiltroEstudiantes.activos),
                ),
                IndicadorPanel(
                  etiqueta: 'Activos hoy',
                  valor: '${r.activosHoy}',
                  nota: 'de $matriculados matriculados',
                  color: p.secundario,
                ),
                IndicadorPanel(
                  etiqueta: 'Por empezar',
                  valor: '${r.programados}',
                  nota: 'matrícula programada',
                  onTap: () =>
                      widget.onVerEstudiantes(FiltroEstudiantes.programados),
                ),
                IndicadorPanel(
                  etiqueta: 'Sin actividad',
                  valor: '${r.sinActividad.length}',
                  nota: '$diasSinActividad días o más',
                  color: r.sinActividad.isEmpty ? null : p.alerta,
                  onTap: () =>
                      widget.onVerEstudiantes(FiltroEstudiantes.sinActividad),
                ),
                IndicadorPanel(
                  etiqueta: 'Registrados sin matrícula',
                  valor: '${r.sinMatricula}',
                  nota: 'tienen cuenta en la app',
                  color: r.sinMatricula == 0 ? null : p.acento,
                  onTap: () =>
                      widget.onVerEstudiantes(FiltroEstudiantes.sinMatricula),
                ),
              ],
            ),
            DosColumnas(
              principal: ColumnaPanel(
                children: [_atencion(r), _ultimasAcciones(acciones, hoy)],
              ),
              lateral: _GraficoSemanas(porSemana: r.porSemana),
            ),
          ],
        );
      },
    );
  }

  Widget _atencion(ResumenPanel r) {
    final p = PaletaPanel.de(context);
    final items = [
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
          for (final a in acciones)
            InkWell(
              onTap: a.usuarioId == null
                  ? null
                  : () => widget.onAbrirEstudiante(a.usuarioId!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(a.descripcion)),
                    const SizedBox(width: 12),
                    Text(
                      haceCuanto(a.fecha, hoy),
                      style: TextStyle(color: p.tenue, fontSize: 12),
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
                        Container(
                          width: 36,
                          height: 4 + 140 * cantidad / maximo,
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
