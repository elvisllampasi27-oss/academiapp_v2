import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ReaccionRespuesta { acierto, error }

/// Al acertar, el contenido da un pequeño salto; al fallar, tiembla de lado
/// a lado. Se anima cuando [reaccion] cambia (o al aparecer, si ya viene
/// con una). Respeta "reducir animaciones" del celular.
class RespuestaAnimada extends StatefulWidget {
  final ReaccionRespuesta? reaccion;
  final Widget child;

  /// Espera antes de animar (para que una lista reaccione en cascada).
  final Duration retraso;

  const RespuestaAnimada({
    super.key,
    required this.reaccion,
    required this.child,
    this.retraso = Duration.zero,
  });

  static const duracion = Duration(milliseconds: 450);

  @override
  State<RespuestaAnimada> createState() => _RespuestaAnimadaState();
}

class _RespuestaAnimadaState extends State<RespuestaAnimada>
    with SingleTickerProviderStateMixin {
  // El retraso va dentro de la misma animación (sin timers sueltos).
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: widget.retraso + RespuestaAnimada.duracion,
  );
  late final Animation<double> _avance = CurvedAnimation(
    parent: _control,
    curve: Interval(
      widget.retraso.inMicroseconds /
          (widget.retraso + RespuestaAnimada.duracion).inMicroseconds,
      1,
    ),
  );

  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciado) {
      _iniciado = true;
      if (widget.reaccion != null) _animar();
    }
  }

  @override
  void didUpdateWidget(RespuestaAnimada anterior) {
    super.didUpdateWidget(anterior);
    if (widget.reaccion != null && widget.reaccion != anterior.reaccion) {
      _animar();
    }
  }

  void _animar() {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _control.forward(from: 0);
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
      builder: (context, child) {
        final t = _avance.value;
        if (t == 0 || t == 1) return child!;
        return switch (widget.reaccion) {
          ReaccionRespuesta.acierto => Transform.scale(
            scale: 1 + 0.06 * math.sin(math.pi * t),
            child: child,
          ),
          ReaccionRespuesta.error => Transform.translate(
            offset: Offset(math.sin(t * math.pi * 4) * 8 * (1 - t), 0),
            child: child,
          ),
          null => child!,
        };
      },
    );
  }
}

/// Una vibración corta al acertar y una más marcada al fallar.
void vibrarRespuesta({required bool acierto}) {
  if (acierto) {
    HapticFeedback.lightImpact();
  } else {
    HapticFeedback.mediumImpact();
  }
}
