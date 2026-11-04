import 'package:flutter/material.dart';

import 'colores_app.dart';

bool _sinAnimaciones(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Solución que se abre y se cierra con "Ver solución". Abierta de entrada
/// cuando el estudiante falló; cerrada cuando acertó, para no saturar.
class SolucionDesplegable extends StatefulWidget {
  final bool abierta;
  final Widget child;

  const SolucionDesplegable({
    super.key,
    required this.abierta,
    required this.child,
  });

  @override
  State<SolucionDesplegable> createState() => _SolucionDesplegableState();
}

class _SolucionDesplegableState extends State<SolucionDesplegable> {
  late bool _abierta = widget.abierta;

  @override
  Widget build(BuildContext context) {
    final duracion = _sinAnimaciones(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _abierta = !_abierta),
          style: TextButton.styleFrom(
            foregroundColor: ColoresApp.ambar,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          icon: AnimatedRotation(
            turns: _abierta ? 0.5 : 0,
            duration: duracion,
            child: const Icon(Icons.expand_more, size: 20),
          ),
          label: Text(_abierta ? 'Ocultar solución' : 'Ver solución'),
        ),
        AnimatedSize(
          duration: duracion,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: _abierta
              ? SizedBox(width: double.infinity, child: widget.child)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Aparece subiendo y desvaneciéndose; con [indice] las tarjetas de una
/// lista entran una tras otra.
class Aparecer extends StatefulWidget {
  final int indice;
  final Widget child;

  const Aparecer({super.key, this.indice = 0, required this.child});

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer>
    with SingleTickerProviderStateMixin {
  static const _entrada = Duration(milliseconds: 380);
  static const _paso = Duration(milliseconds: 70);

  /// Desde la 8.ª tarjeta ya no se espera más (una lista larga no tarda).
  late final Duration _retraso =
      _paso * (widget.indice < 8 ? widget.indice : 8);

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: _retraso + _entrada,
  );
  late final Animation<double> _avance = CurvedAnimation(
    parent: _control,
    curve: Interval(
      _retraso.inMicroseconds / (_retraso + _entrada).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control.isAnimating || _control.isCompleted) return;
    if (_sinAnimaciones(context)) {
      _control.value = 1;
    } else {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _avance,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _avance.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - _avance.value)),
          child: child,
        ),
      ),
    );
  }
}
