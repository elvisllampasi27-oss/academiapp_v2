import 'package:flutter/material.dart';

import '../animacion_panel.dart';
import '../../core/presentation/formato_fecha.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'sonda_sistema.dart';

/// Si la base de datos, las funciones y Storage responden, y lo que está
/// esperando una acción del equipo.
class EstadoSistemaPage extends StatefulWidget {
  final SondaSistema sonda;
  final Stream<int> pagosPendientes;
  final Stream<int> reportesNuevos;
  final VoidCallback onVerPagos;
  final VoidCallback onVerReportes;
  final DateTime Function() ahora;

  const EstadoSistemaPage({
    super.key,
    required this.sonda,
    required this.pagosPendientes,
    required this.reportesNuevos,
    required this.onVerPagos,
    required this.onVerReportes,
    this.ahora = DateTime.now,
  });

  @override
  State<EstadoSistemaPage> createState() => _EstadoSistemaPageState();
}

/// Lo pendiente antes de pasar al plan Blaze (producción).
const pasosAntesDeBlaze = [
  'Actualizar firebase-functions a la última versión y desplegar las '
      'funciones.',
  'Desplegar las reglas de Storage (firebase deploy --only storage).',
  'Activar App Check en la app y en el panel.',
  'Crear un proyecto aparte para pruebas (dev) y dejar este solo para '
      'producción.',
  'Cambiar la contraseña de la cuenta de prueba del estudiante.',
  'Poner un presupuesto con alertas en Google Cloud.',
];

class _EstadoSistemaPageState extends State<EstadoSistemaPage> {
  late Future<List<ChequeoServicio>> _chequeos = widget.sonda.revisar();
  late DateTime _revisado = widget.ahora();

  void _revisar() {
    setState(() {
      _revisado = widget.ahora();
      _chequeos = widget.sonda.revisar();
    });
  }

  Color _color(PaletaPanel p, NivelEstado n) => switch (n) {
    NivelEstado.bien => p.secundario,
    NivelEstado.atencion => p.acento,
    NivelEstado.caido => p.alerta,
  };

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final entorno = widget.sonda.entorno;
    return PaginaPanel(
      children: [
        EncabezadoPanel(
          titulo: 'Estado del sistema',
          subtitulo:
              'Si cada servicio responde y lo que está esperando al equipo. '
              'Revisado a las ${horaCorta(_revisado)}',
          acciones: [
            OutlinedButton.icon(
              onPressed: _revisar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Revisar de nuevo'),
            ),
          ],
        ),
        FutureBuilder<List<ChequeoServicio>>(
          future: _chequeos,
          builder: (context, s) {
            final chequeos = s.data;
            if (chequeos == null) {
              return const TarjetaPanel(
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 14),
                    Expanded(child: Text('Revisando servicios…')),
                  ],
                ),
              );
            }
            final peor = chequeos.fold(
              NivelEstado.bien,
              (m, c) => c.nivel.index > m.index ? c.nivel : m,
            );
            return ColumnaPanel(
              children: [
                TarjetaPanel(
                  child: PildoraEstado(switch (peor) {
                    NivelEstado.bien => 'Todo funciona',
                    NivelEstado.atencion => 'Funciona, con avisos',
                    NivelEstado.caido => 'Hay servicios que no responden',
                  }, color: _color(p, peor)),
                ),
                RejillaPanel(
                  anchoMinimo: 280,
                  children: [
                    for (final (iFila, c) in chequeos.indexed)
                      FilaEntrante(
                        indice: iFila,
                        child: TarjetaPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.servicio,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              PildoraEstado(switch (c.nivel) {
                                NivelEstado.bien => 'Responde',
                                NivelEstado.atencion => 'Atención',
                                NivelEstado.caido => 'No responde',
                              }, color: _color(p, c.nivel)),
                              const SizedBox(height: 10),
                              Text(
                                c.detalle,
                                style: TextStyle(color: p.apagado, height: 1.4),
                              ),
                              if (c.milisegundos case final ms?) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '$ms ms',
                                  style: TextStyle(
                                    color: p.tenue,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        DosColumnas(
          principal: TarjetaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TituloTarjeta('Esperando al equipo'),
                _Pendiente(
                  etiqueta: 'Pagos por revisar',
                  cantidad: widget.pagosPendientes,
                  onVer: widget.onVerPagos,
                ),
                _Pendiente(
                  etiqueta: 'Reportes nuevos de la app',
                  cantidad: widget.reportesNuevos,
                  onVer: widget.onVerReportes,
                ),
              ],
            ),
          ),
          lateral: TarjetaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TituloTarjeta('Dónde corre'),
                FilaDato('Proyecto', entorno.proyecto),
                FilaDato(
                  'Funciones',
                  entorno.emuladorFunctions ? 'Emulador local' : 'Nube',
                ),
                FilaDato(
                  'Archivos',
                  entorno.emuladorStorage ? 'Emulador local' : 'Nube',
                ),
              ],
            ),
          ),
        ),
        TarjetaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TituloTarjeta('Antes de activar Blaze'),
              for (final (i, paso) in pasosAntesDeBlaze.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}.',
                          style: TextStyle(
                            color: p.acento,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          paso,
                          style: TextStyle(color: p.apagado, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pendiente extends StatelessWidget {
  final String etiqueta;
  final Stream<int> cantidad;
  final VoidCallback onVer;

  const _Pendiente({
    required this.etiqueta,
    required this.cantidad,
    required this.onVer,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return StreamBuilder<int>(
      stream: cantidad,
      builder: (context, s) {
        final n = s.data;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PaletaPanel.linea)),
          ),
          child: Row(
            children: [
              Expanded(child: Text(etiqueta)),
              Text(
                n == null ? '…' : '$n',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: (n ?? 0) > 0 ? p.acento : p.apagado,
                ),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: onVer, child: const Text('Ver')),
            ],
          ),
        );
      },
    );
  }
}
