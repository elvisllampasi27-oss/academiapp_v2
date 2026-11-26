import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/formato_fecha.dart';
import '../../../premium/domain/repositorio_premium.dart';
import '../../domain/errors/excepcion_autenticacion.dart';
import '../../domain/repositories/servicio_eliminacion_cuenta.dart';
import '../../domain/values/avisos_eliminacion.dart';
import '../messages/mensajes_autenticacion.dart';

/// Perfil → Eliminar mi cuenta. Explica qué se borra, avisa si tiene
/// Premium o un pago en revisión (no hay reembolso), pide escribir ELIMINAR
/// y volver a identificarse, y borra todo en el servidor.
class EliminarCuentaPage extends StatefulWidget {
  final ServicioEliminacionCuenta servicio;

  /// Plan y pagos del alumno, para los avisos (puede fallar: hay un aviso
  /// general igual).
  final Future<EstadoPremium?> Function() cargarPremium;

  /// Después de borrar: cierra la sesión.
  final Future<void> Function() onEliminada;
  final DateTime Function() ahora;

  const EliminarCuentaPage({
    super.key,
    required this.servicio,
    required this.cargarPremium,
    required this.onEliminada,
    this.ahora = DateTime.now,
  });

  @override
  State<EliminarCuentaPage> createState() => _EliminarCuentaPageState();
}

class _EliminarCuentaPageState extends State<EliminarCuentaPage> {
  late final Future<AvisosEliminacion> _avisos = _cargarAvisos();
  late final MetodoIngreso _metodo = widget.servicio.metodoIngreso();
  final _confirmacion = TextEditingController();
  final _contrasena = TextEditingController();
  bool _cargando = false;
  String? _error;

  Future<AvisosEliminacion> _cargarAvisos() async {
    final estado = await widget.cargarPremium();
    return AvisosEliminacion.desde(estado, widget.ahora());
  }

  @override
  void dispose() {
    _confirmacion.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  bool get _listo =>
      confirmacionValida(_confirmacion.text) &&
      (_metodo == MetodoIngreso.google || _contrasena.text.isNotEmpty);

  Future<void> _eliminar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (_metodo == MetodoIngreso.contrasena) {
        await widget.servicio.reautenticarConContrasena(_contrasena.text);
      } else {
        await widget.servicio.reautenticarConGoogle();
      }
      await widget.servicio.eliminarMiCuenta();
      if (!mounted) return;
      setState(() => _cargando = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Tu cuenta fue eliminada'),
          content: const Text(
            'Borramos tu cuenta y tus datos. Gracias por estudiar con '
            'Sinchi. ¡Éxitos en tu postulación!',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      final alTerminar = widget.onEliminada;
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
      await alTerminar();
    } on ExcepcionEliminacionCuenta catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on ExcepcionAutenticacion catch (e) {
      if (mounted) setState(() => _error = mensajeErrorAutenticacion(e));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo eliminar la cuenta. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const Text(
            'Esto borra tu cuenta para siempre',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const _Punto(
            icono: Icons.delete_outline,
            texto:
                'Se borra: tu perfil, tu avance, tus prácticas y exámenes, '
                'tu lugar en el ranking y tus reportes.',
          ),
          const _Punto(
            icono: Icons.receipt_long_outlined,
            texto:
                'Se guarda sin tu nombre: el registro de tus pagos (monto, '
                'fecha y número de operación), por temas contables.',
          ),
          const _Punto(
            icono: Icons.money_off_outlined,
            texto:
                'Si tienes Premium, pierdes los días que te queden. '
                'No hay reembolso.',
          ),
          const _Punto(icono: Icons.undo, texto: 'No se puede deshacer.'),
          FutureBuilder<AvisosEliminacion>(
            future: _avisos,
            builder: (context, snapshot) {
              final avisos = snapshot.data;
              if (avisos == null) return const SizedBox(height: 8);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (avisos.premiumHasta case final hasta?)
                    _Aviso(
                      texto:
                          'Tienes Premium hasta el ${fechaCorta(hasta)} '
                          '(${avisos.diasPremium} '
                          '${avisos.diasPremium == 1 ? 'día' : 'días'}). '
                          'Si eliminas tu cuenta pierdes esos días y no hay '
                          'reembolso.',
                    ),
                  if (avisos.pagoPendiente)
                    const _Aviso(
                      texto:
                          'Tienes un pago en revisión. Si eliminas tu cuenta, '
                          'ese pago no se activará y no hay reembolso.',
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmacion,
            enabled: !_cargando,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Escribe $palabraConfirmacion para confirmar',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (_metodo == MetodoIngreso.contrasena)
            TextField(
              controller: _contrasena,
              enabled: !_cargando,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Tu contraseña'),
              onChanged: (_) => setState(() {}),
            )
          else
            const Text(
              'Te pediremos elegir de nuevo tu cuenta de Google.',
              style: TextStyle(color: ColoresApp.apagado),
            ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(color: ColoresApp.naranja)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _listo && !_cargando ? _eliminar : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            icon: _cargando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: const Text('Eliminar mi cuenta'),
          ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Punto({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: ColoresApp.apagado),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;

  const _Aviso({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.ambar.withValues(alpha: 0.12),
        border: Border.all(color: ColoresApp.ambar.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: ColoresApp.ambar),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
