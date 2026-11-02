import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/premium/domain/configuracion_academia.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../estudiantes/repositorio_estudiantes_admin.dart';
import '../pagos/repositorio_pagos_admin.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';

/// Reglas generales: precio de Premium, datos de Yape, límites del plan
/// gratis y el registro de acciones del panel.
class ConfiguracionPage extends StatefulWidget {
  final RepositorioAcademiaAdmin academia;
  final RepositorioEstudiantesAdmin estudiantes;
  final DateTime Function() ahora;

  const ConfiguracionPage({
    super.key,
    required this.academia,
    required this.estudiantes,
    this.ahora = DateTime.now,
  });

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  late Future<(ConfiguracionAcademia, List<AccionAdmin>)> _datos = _cargar();

  final _precio = TextEditingController();
  final _dias = TextEditingController();
  final _yape = TextEditingController();
  final _titular = TextEditingController();
  final _whatsapp = TextEditingController();
  final _tutorGratis = TextEditingController();
  final _tutorPremium = TextEditingController();
  bool _foto = false;
  bool _simulacroPremium = true;
  bool _guardando = false;

  Future<(ConfiguracionAcademia, List<AccionAdmin>)> _cargar() async {
    final c = await widget.academia.configuracion();
    final acciones = await widget.estudiantes.accionesRecientes(limite: 30);
    _precio.text = '${c.precio}';
    _dias.text = '${c.diasPremium}';
    _yape.text = c.yapeNumero;
    _titular.text = c.yapeTitular;
    _whatsapp.text = c.whatsapp;
    _tutorGratis.text = '${c.tutorGratis}';
    _tutorPremium.text = '${c.tutorPremium}';
    _foto = c.fotoComprobante;
    _simulacroPremium = c.simulacroSoloPremium;
    return (c, acciones);
  }

  @override
  void dispose() {
    for (final c in [
      _precio,
      _dias,
      _yape,
      _titular,
      _whatsapp,
      _tutorGratis,
      _tutorPremium,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _entero(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _guardar() async {
    final precio = _entero(_precio);
    final dias = _entero(_dias);
    final gratis = _entero(_tutorGratis);
    final premium = _entero(_tutorPremium);
    final error = precio == null || precio < 0
        ? 'Revisa el precio.'
        : dias == null || dias < 1
        ? 'Revisa los días de Premium.'
        : gratis == null || premium == null || gratis < 0 || premium < gratis
        ? 'Las dudas de Premium deben ser al menos las del plan gratis.'
        : null;
    if (error != null) {
      avisarPanel(context, error);
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.academia.guardarConfiguracion(
        ConfiguracionAcademia(
          precio: precio!,
          diasPremium: dias!,
          yapeNumero: _yape.text.trim(),
          yapeTitular: _titular.text.trim(),
          whatsapp: _whatsapp.text.trim(),
          fotoComprobante: _foto,
          tutorGratis: gratis!,
          tutorPremium: premium!,
          simulacroSoloPremium: _simulacroPremium,
        ),
      );
      if (!mounted) return;
      avisarPanel(context, 'Configuración guardada.');
      setState(() {
        _datos = _cargar();
      });
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel(
      futuro: _datos,
      onReintentar: () => setState(() {
        _datos = _cargar();
      }),
      builder: (context, datos) {
        final (_, acciones) = datos;
        final p = PaletaPanel.de(context);
        final hoy = widget.ahora();

        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Configuración',
              subtitulo:
                  'Reglas generales de la academia. La app y el servidor las '
                  'leen al momento.',
              acciones: [
                FilledButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Guardar cambios'),
                ),
              ],
            ),
            DosColumnas(
              flexPrincipal: 1,
              principal: ColumnaPanel(
                children: [
                  _tarjeta('Plan Premium', [
                    _par(
                      _campo(_precio, 'Precio (S/)', numero: true),
                      _campo(_dias, 'Duración (días)', numero: true),
                    ),
                  ]),
                  _tarjeta('Pago por Yape o Plin', [
                    _par(
                      _campo(_yape, 'Número de Yape/Plin', numero: true),
                      _campo(_titular, 'A nombre de'),
                    ),
                    _campo(
                      _whatsapp,
                      'WhatsApp para comprobantes',
                      numero: true,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _foto,
                      onChanged: (v) => setState(() => _foto = v),
                      title: const Text('Foto del comprobante desde la app'),
                      subtitle: Text(
                        'Necesita Firebase Storage (plan Blaze). Mientras '
                        'esté apagado, el estudiante manda la captura por '
                        'WhatsApp.',
                        style: TextStyle(color: p.tenue, fontSize: 12),
                      ),
                    ),
                  ]),
                  _tarjeta('Plan gratis y Premium', [
                    _par(
                      _campo(
                        _tutorGratis,
                        'Dudas al tutor por día (gratis)',
                        numero: true,
                      ),
                      _campo(
                        _tutorPremium,
                        'Dudas al tutor por día (Premium)',
                        numero: true,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _simulacroPremium,
                      onChanged: (v) => setState(() => _simulacroPremium = v),
                      title: const Text(
                        'Examen tipo admisión solo para Premium',
                      ),
                    ),
                  ]),
                ],
              ),
              lateral: TarjetaPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TituloTarjeta(
                      'Registro de acciones',
                      extra: Text(
                        'quién hizo qué y cuándo',
                        style: TextStyle(color: p.tenue, fontSize: 12),
                      ),
                    ),
                    if (acciones.isEmpty)
                      Text('Sin acciones.', style: TextStyle(color: p.apagado)),
                    for (final a in acciones)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: PaletaPanel.linea),
                          ),
                        ),
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tarjeta(String titulo, List<Widget> hijos) => TarjetaPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloTarjeta(titulo),
        ColumnaPanel(espacio: 12, children: hijos),
      ],
    ),
  );

  Widget _par(Widget a, Widget b) => Row(
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );

  Widget _campo(
    TextEditingController c,
    String etiqueta, {
    bool numero = false,
  }) => TextField(
    controller: c,
    keyboardType: numero ? TextInputType.number : TextInputType.text,
    inputFormatters: numero ? [FilteringTextInputFormatter.digitsOnly] : null,
    decoration: InputDecoration(labelText: etiqueta),
  );
}
