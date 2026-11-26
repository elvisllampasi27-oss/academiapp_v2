import 'package:flutter/material.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/formato_fecha.dart';
import '../domain/services/servicio_preparacion_cuenta.dart';

/// "lunes 30 nov", para usar dentro de una frase.
String fechaEnFrase(DateTime fecha) => fechaCorta(fecha).toLowerCase();

/// El alumno todavía no tiene plan: se lo prepara solo (matrícula en la
/// versión vigente y prueba gratis), le da la bienvenida y entra.
class PrepararPlan extends StatefulWidget {
  final ServicioPreparacionCuenta servicio;
  final String nombre;

  /// Ya tiene plan: recargar el inicio.
  final VoidCallback onListo;

  /// Si no se pudo: la pantalla con el motivo y un "Reintentar".
  final Widget Function(String mensaje, VoidCallback reintentar) siFalla;

  const PrepararPlan({
    super.key,
    required this.servicio,
    required this.nombre,
    required this.onListo,
    required this.siFalla,
  });

  @override
  State<PrepararPlan> createState() => _PrepararPlanState();
}

class _PrepararPlanState extends State<PrepararPlan> {
  String? _error;

  /// Ya quedó listo: deja de girar la carga (debajo de la bienvenida).
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  Future<void> _preparar() async {
    try {
      final plan = await widget.servicio.preparar();
      if (!mounted) return;
      setState(() => _listo = true);
      if (plan.nuevo) await _bienvenida(plan);
      if (mounted) widget.onListo();
    } on ExcepcionPreparacionCuenta catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos preparar tu plan. Inténtalo de nuevo.',
        );
      }
    }
  }

  void _reintentar() {
    setState(() => _error = null);
    _preparar();
  }

  Future<void> _bienvenida(PlanPreparado plan) {
    final primerNombre = widget.nombre.trim().split(RegExp(r'\s+')).first;
    final inicio = plan.inicio;
    final ultimoDia = plan.ultimoDiaPrueba;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('¡Bienvenido a Sinchi, $primerNombre!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inicio != null)
              Text(
                'Tu plan empieza el ${fechaEnFrase(inicio)}. Ese día verás en '
                'el Inicio los temas que te tocan.',
              ),
            if (ultimoDia != null) ...[
              const SizedBox(height: 12),
              Text(
                'Tu prueba gratis, con todo incluido, dura hasta el '
                '${fechaEnFrase(ultimoDia)}: alcanza para rendir tu primer '
                'examen semanal.',
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Empezar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error case final error?) return widget.siFalla(error, _reintentar);
    if (_listo) return const Scaffold();
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Preparando tu plan…',
              style: TextStyle(color: ColoresApp.apagado),
            ),
          ],
        ),
      ),
    );
  }
}
