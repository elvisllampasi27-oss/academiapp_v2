import 'package:flutter/material.dart';

import '../../core/presentation/texto.dart';
import '../../features/premium/domain/configuracion_academia.dart';
import '../../features/premium/domain/pago.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'repositorio_pagos_admin.dart';

/// Pagos de Premium por Yape/Plin y becas: se revisan y se aprueban aquí.
class PagosPage extends StatefulWidget {
  final RepositorioPagosAdmin pagos;
  final RepositorioAcademiaAdmin academia;
  final ValueChanged<String> onAbrirEstudiante;
  final DateTime Function() ahora;

  const PagosPage({
    super.key,
    required this.pagos,
    required this.academia,
    required this.onAbrirEstudiante,
    this.ahora = DateTime.now,
  });

  @override
  State<PagosPage> createState() => _PagosPageState();
}

class _PagosPageState extends State<PagosPage> {
  EstadoPago _estado = EstadoPago.pendiente;
  late Future<(List<Pago>, ConfiguracionAcademia)> _datos = _cargar();
  String _texto = '';
  String? _elegidoId;
  bool _ocupado = false;
  final _verificado = <int>{};

  Future<(List<Pago>, ConfiguracionAcademia)> _cargar() async {
    final pagos = await widget.pagos.pagos(_estado);
    final config = await widget.academia.configuracion();
    return (pagos, config);
  }

  void _recargar() => setState(() {
    _datos = _cargar();
    _verificado.clear();
  });

  void _cambiarEstado(EstadoPago e) => setState(() {
    _estado = e;
    _elegidoId = null;
    _datos = _cargar();
    _verificado.clear();
  });

  Future<void> _hacer(Future<String> Function() accion) async {
    setState(() => _ocupado = true);
    try {
      final mensaje = await accion();
      if (!mounted) return;
      avisarPanel(context, mensaje);
      setState(() => _elegidoId = null);
      _recargar();
    } catch (e) {
      if (mounted) {
        avisarPanel(context, e is StateError ? e.message : 'No se pudo: $e');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _aprobar(Pago p, ConfiguracionAcademia c) => _hacer(() async {
    final hasta = await widget.pagos.aprobar(p, dias: c.diasPremium);
    return 'Aprobado: ${p.nombre} es Premium hasta el ${fechaPanel(hasta)}.';
  });

  Future<void> _rechazar(Pago p) async {
    final motivo = await pedirTexto(
      context,
      titulo: 'Rechazar pago',
      etiqueta: 'Motivo (lo verá el estudiante)',
      sugerencias: const [
        'No encontramos la operación en Yape',
        'El monto no coincide',
        'El comprobante no es legible',
      ],
      confirmar: 'Rechazar',
    );
    if (motivo == null) return;
    await _hacer(() async {
      await widget.pagos.rechazar(p, motivo: motivo);
      return 'Pago rechazado.';
    });
  }

  Future<void> _revertir(Pago p) => _hacer(() async {
    await widget.pagos.revertir(p);
    return 'El pago volvió a "Por revisar".';
  });

  @override
  Widget build(BuildContext context) {
    return FuturoPanel(
      futuro: _datos,
      onReintentar: _recargar,
      builder: (context, datos) {
        final (todos, config) = datos;
        final buscado = normalizarTexto(_texto.trim());
        final lista = todos
            .where(
              (p) => normalizarTexto(
                '${p.nombre} ${p.correo} ${p.operacion} ${p.cupon ?? ''}',
              ).contains(buscado),
            )
            .toList();
        final elegido =
            lista.where((p) => p.id == _elegidoId).firstOrNull ??
            lista.firstOrNull;

        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Pagos',
              subtitulo:
                  'Premium: S/ ${config.precio} por ${config.diasPremium} '
                  'días. Los pagos por Yape o Plin los confirmas tú; nada se '
                  'borra.',
              acciones: [
                OutlinedButton.icon(
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (e, t) in const [
                  (EstadoPago.pendiente, 'Por revisar'),
                  (EstadoPago.aprobado, 'Aprobados'),
                  (EstadoPago.rechazado, 'Rechazados'),
                ])
                  ChoiceChip(
                    label: Text(
                      e == _estado && e == EstadoPago.pendiente
                          ? '$t · ${todos.length}'
                          : t,
                    ),
                    selected: _estado == e,
                    onSelected: (_) => _cambiarEstado(e),
                  ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    onChanged: (t) => setState(() => _texto = t),
                    decoration: const InputDecoration(
                      hintText: 'Buscar estudiante, N.º o cupón',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ],
            ),
            if (lista.isEmpty)
              TarjetaPanel(
                child: Text(
                  _estado == EstadoPago.pendiente
                      ? 'No hay pagos por revisar.'
                      : 'No hay pagos aquí.',
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
                    for (final p in lista)
                      _TarjetaPago(
                        pago: p,
                        elegido: p.id == elegido?.id,
                        ahora: widget.ahora(),
                        onTap: () => setState(() {
                          _elegidoId = p.id;
                          _verificado.clear();
                        }),
                      ),
                  ],
                ),
                lateral: _detalle(elegido!, config),
              ),
          ],
        );
      },
    );
  }

  Widget _detalle(Pago p, ConfiguracionAcademia c) {
    final paleta = PaletaPanel.de(context);
    final revisar = p.estado == EstadoPago.pendiente;
    final esperado = p.metodo == MetodoPago.beca ? 0 : p.monto;
    final checks = p.metodo == MetodoPago.beca
        ? ['El cupón ${p.cupon} corresponde a este estudiante']
        : [
            'Llegó S/ $esperado al Yape de la academia',
            'El N.º de operación ${p.operacion} coincide',
            if (p.cupon != null)
              'El cupón ${p.cupon} justifica el monto (precio normal '
                  'S/ ${c.precio})',
          ];
    final hasta = premiumNuevoHasta(null, widget.ahora(), c.diasPremium);

    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            p.nombre,
            extra: TextButton(
              onPressed: () => widget.onAbrirEstudiante(p.usuarioId),
              child: const Text('Ver ficha'),
            ),
          ),
          FilaDato('Correo', p.correo),
          FilaDato('Método', p.metodo.etiqueta),
          if (p.metodo != MetodoPago.beca) ...[
            FilaDato('Monto', 'S/ ${p.monto}'),
            FilaDato('N.º de operación', p.operacion),
          ],
          if (p.cupon case final cupon?) FilaDato('Cupón', cupon),
          FilaDato(
            'Enviado',
            '${fechaPanel(p.creadoEn)} · ${haceCuanto(p.creadoEn, widget.ahora())}',
          ),
          if (p.revisadoPor != null)
            FilaDato(
              'Revisó',
              '${p.revisadoPor}${p.revisadoEn == null ? '' : ' · ${fechaPanel(p.revisadoEn!)}'}',
            ),
          if (p.motivo case final m?) FilaDato('Motivo', m),
          if (p.premiumHasta case final h?)
            FilaDato('Premium hasta', fechaPanel(h)),
          const SizedBox(height: 14),
          if (p.fotoUrl case final url?)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                height: 360,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Text(
                  'No se pudo mostrar la foto.',
                  style: TextStyle(color: paleta.alerta),
                ),
              ),
            )
          else if (p.metodo != MetodoPago.beca && revisar)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: paleta.acento.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: paleta.acento.withValues(alpha: 0.25),
                ),
              ),
              child: const Text(
                'Sin foto en la app: revisa la captura que te mandó por '
                'WhatsApp y busca la operación en tu Yape.',
              ),
            ),
          if (revisar) ...[
            const SizedBox(height: 16),
            Text(
              'ANTES DE APROBAR, VERIFICA',
              style: TextStyle(
                color: paleta.tenue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            for (final (i, texto) in checks.indexed)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _verificado.contains(i),
                onChanged: (v) => setState(
                  () => v == true ? _verificado.add(i) : _verificado.remove(i),
                ),
                title: Text(texto),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: paleta.alerta,
                    side: BorderSide(
                      color: paleta.alerta.withValues(alpha: 0.45),
                    ),
                  ),
                  onPressed: _ocupado ? null : () => _rechazar(p),
                  child: const Text('Rechazar con motivo'),
                ),
                FilledButton.icon(
                  onPressed: _ocupado || _verificado.length < checks.length
                      ? null
                      : () => _aprobar(p, c),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text('Aprobar · Premium hasta ${fechaBreve(hasta)}*'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '* Si todavía es Premium, los ${c.diasPremium} días se suman a '
              'lo que le queda.',
              style: TextStyle(color: paleta.tenue, fontSize: 12),
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _ocupado ? null : () => _revertir(p),
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Revertir a "Por revisar"'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TarjetaPago extends StatelessWidget {
  final Pago pago;
  final bool elegido;
  final DateTime ahora;
  final VoidCallback onTap;

  const _TarjetaPago({
    required this.pago,
    required this.elegido,
    required this.ahora,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final detalle = switch (pago.metodo) {
      MetodoPago.beca => 'Beca · ${pago.cupon}',
      MetodoPago.manual => 'Dado por el administrador · ${pago.motivo ?? ''}',
      _ =>
        'S/ ${pago.monto} · ${pago.metodo.etiqueta} · N.º ${pago.operacion}'
            '${pago.cupon == null ? '' : ' · cupón ${pago.cupon}'}',
    };
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
                width: 44,
                height: 52,
                decoration: BoxDecoration(
                  color: PaletaPanel.linea,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  pago.fotoUrl != null
                      ? Icons.image_outlined
                      : pago.metodo == MetodoPago.beca
                      ? Icons.school_outlined
                      : Icons.receipt_long_outlined,
                  color: p.apagado,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pago.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      pago.correo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.apagado, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.apagado, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                haceCuanto(pago.creadoEn, ahora),
                style: TextStyle(color: p.tenue, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
