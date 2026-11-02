import 'package:flutter/material.dart';

import '../../features/premium/domain/cupon.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'repositorio_pagos_admin.dart';

/// Cupones de descuento y becas (Premium gratis). Se usan al pagar en la
/// app; cada uso se cuenta cuando apruebas el pago.
class CuponesPage extends StatefulWidget {
  final RepositorioAcademiaAdmin repositorio;
  final DateTime Function() ahora;

  const CuponesPage({
    super.key,
    required this.repositorio,
    this.ahora = DateTime.now,
  });

  @override
  State<CuponesPage> createState() => _CuponesPageState();
}

class _CuponesPageState extends State<CuponesPage> {
  late Future<List<Cupon>> _cupones = widget.repositorio.cupones();

  void _recargar() => setState(() => _cupones = widget.repositorio.cupones());

  Future<void> _editar([Cupon? cupon]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoCupon(
        repositorio: widget.repositorio,
        cupon: cupon,
        ahora: widget.ahora,
      ),
    );
    if (guardado == true && mounted) {
      avisarPanel(context, 'Cupón guardado.');
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel(
      futuro: _cupones,
      onReintentar: _recargar,
      builder: (context, cupones) {
        final p = PaletaPanel.de(context);
        final ahora = widget.ahora();
        const columnas = [
          ('CÓDIGO', 2),
          ('BENEFICIO', 3),
          ('USOS', 2),
          ('VIGENCIA', 2),
          ('ESTADO', 2),
          ('', 1),
        ];

        Widget fila(List<Widget> celdas, {bool cabecera = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: cabecera ? PaletaPanel.bordeFuerte : PaletaPanel.linea,
              ),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < celdas.length; i++)
                Expanded(flex: columnas[i].$2, child: celdas[i]),
            ],
          ),
        );

        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Cupones y becas',
              subtitulo:
                  'Descuentos al pagar y Premium gratis para becados. El '
                  'estudiante escribe el código en "Premium".',
              acciones: [
                FilledButton.icon(
                  onPressed: () => _editar(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo cupón'),
                ),
              ],
            ),
            TarjetaPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  fila(cabecera: true, [
                    for (final (t, _) in columnas)
                      Text(
                        t,
                        maxLines: 1,
                        style: TextStyle(
                          color: p.tenue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                  ]),
                  if (cupones.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'Todavía no hay cupones.',
                        style: TextStyle(color: p.apagado),
                      ),
                    ),
                  for (final c in cupones)
                    fila([
                      Text(
                        c.codigo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(c.beneficio),
                      Text(
                        c.usosMaximos == null
                            ? '${c.usos} usos'
                            : '${c.usos} de ${c.usosMaximos}',
                        style: TextStyle(color: p.apagado),
                      ),
                      Text(
                        c.vence == null
                            ? 'Sin vencimiento'
                            : 'Hasta ${fechaBreve(c.vence!)}',
                        style: TextStyle(color: p.apagado),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: c.vigente(ahora)
                            ? const Insignia(
                                'Activo',
                                tono: TonoInsignia.secundario,
                              )
                            : Insignia(
                                !c.activo
                                    ? 'Desactivado'
                                    : c.usosMaximos != null &&
                                          c.usos >= c.usosMaximos!
                                    ? 'Agotado'
                                    : 'Vencido',
                              ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Editar',
                          onPressed: () => _editar(c),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DialogoCupon extends StatefulWidget {
  final RepositorioAcademiaAdmin repositorio;
  final Cupon? cupon;
  final DateTime Function() ahora;

  const _DialogoCupon({
    required this.repositorio,
    required this.cupon,
    required this.ahora,
  });

  @override
  State<_DialogoCupon> createState() => _DialogoCuponState();
}

class _DialogoCuponState extends State<_DialogoCupon> {
  late final _codigo = TextEditingController(text: widget.cupon?.codigo);
  late final _valor = TextEditingController(
    text: widget.cupon == null ? '' : '${widget.cupon!.valor}',
  );
  late final _usos = TextEditingController(
    text: widget.cupon?.usosMaximos?.toString() ?? '',
  );
  late TipoCupon _tipo = widget.cupon?.tipo ?? TipoCupon.descuento;
  late DateTime? _vence = widget.cupon?.vence;
  late bool _activo = widget.cupon?.activo ?? true;
  bool _guardando = false;
  String? _error;

  bool get _nuevo => widget.cupon == null;

  @override
  void dispose() {
    _codigo.dispose();
    _valor.dispose();
    _usos.dispose();
    super.dispose();
  }

  Future<void> _elegirVence() async {
    final hoy = widget.ahora();
    final f = await showDatePicker(
      context: context,
      initialDate: _vence ?? hoy.add(const Duration(days: 30)),
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 3),
      helpText: 'Vence el',
    );
    if (f != null) {
      setState(() => _vence = DateTime(f.year, f.month, f.day, 23, 59));
    }
  }

  Future<void> _guardar() async {
    final codigo = normalizarCodigo(_codigo.text);
    final valor = int.tryParse(_valor.text.trim()) ?? 0;
    final usos = int.tryParse(_usos.text.trim());
    final error = codigo.length < 3
        ? 'El código debe tener al menos 3 letras o números.'
        : _tipo == TipoCupon.descuento && (valor < 1 || valor > 100)
        ? 'El descuento va de 1 a 100 %.'
        : _tipo == TipoCupon.precioFijo && valor < 1
        ? 'Escribe el precio que pagará.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repositorio.guardarCupon(
        Cupon(
          codigo: codigo,
          tipo: _tipo,
          valor: _tipo == TipoCupon.premiumGratis ? 0 : valor,
          usosMaximos: usos,
          usos: widget.cupon?.usos ?? 0,
          vence: _vence,
          activo: _activo,
        ),
        nuevo: _nuevo,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e is StateError ? e.message : 'No se pudo guardar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return AlertDialog(
      title: Text(_nuevo ? 'Nuevo cupón' : 'Editar ${widget.cupon!.codigo}'),
      content: SizedBox(
        width: 460,
        child: ColumnaPanel(
          espacio: 14,
          children: [
            if (_nuevo)
              TextField(
                controller: _codigo,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  hintText: 'BECA50',
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in TipoCupon.values)
                  ChoiceChip(
                    label: Text(t.etiqueta),
                    selected: _tipo == t,
                    onSelected: (_) => setState(() => _tipo = t),
                  ),
              ],
            ),
            if (_tipo != TipoCupon.premiumGratis)
              TextField(
                controller: _valor,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _tipo == TipoCupon.descuento
                      ? 'Descuento (%)'
                      : 'Paga (S/)',
                ),
              ),
            TextField(
              controller: _usos,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Usos máximos (vacío = sin límite)',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _vence == null
                        ? 'Sin vencimiento'
                        : 'Vence el ${fechaPanel(_vence!)}',
                  ),
                ),
                if (_vence != null)
                  TextButton(
                    onPressed: () => setState(() => _vence = null),
                    child: const Text('Quitar'),
                  ),
                OutlinedButton(
                  onPressed: _elegirVence,
                  child: const Text('Elegir fecha'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
              title: const Text('Activo'),
              subtitle: Text(
                'Desactívalo en vez de borrarlo: los pagos que lo usaron '
                'lo siguen mostrando.',
                style: TextStyle(color: p.tenue, fontSize: 12),
              ),
            ),
            if (_error case final e?)
              Text(e, style: TextStyle(color: p.alerta)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
