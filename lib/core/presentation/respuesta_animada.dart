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

  static const duracion = Duration(milliseconds: 600);

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
            scale: 1 + 0.12 * math.sin(math.pi * t),
            child: child,
          ),
          ReaccionRespuesta.error => Transform.translate(
            offset: Offset(math.sin(t * math.pi * 4) * 12 * (1 - t), 0),
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

/// Marca que se dibuja sola (path draw): primero el círculo y luego el ✓
/// (o la ✗). Con "reducir animaciones" aparece completa.
class MarcaDibujada extends StatefulWidget {
  final bool correcta;
  final double tamano;
  final Color color;
  final Duration retraso;

  const MarcaDibujada({
    super.key,
    required this.correcta,
    required this.color,
    this.tamano = 24,
    this.retraso = Duration.zero,
  });

  static const duracion = Duration(milliseconds: 900);

  @override
  State<MarcaDibujada> createState() => _MarcaDibujadaState();
}

class _MarcaDibujadaState extends State<MarcaDibujada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: widget.retraso + MarcaDibujada.duracion,
  );
  late final Animation<double> _avance = CurvedAnimation(
    parent: _control,
    curve: Interval(
      widget.retraso.inMicroseconds /
          (widget.retraso + MarcaDibujada.duracion).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control.isAnimating || _control.isCompleted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _control.value = 1;
    } else {
      _control.forward();
    }
  }

  @override
  void didUpdateWidget(MarcaDibujada anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.correcta != widget.correcta) _control.forward(from: 0);
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.correcta ? 'Correcta' : 'Incorrecta',
      child: SizedBox.square(
        dimension: widget.tamano,
        child: AnimatedBuilder(
          animation: _avance,
          builder: (context, _) => CustomPaint(
            painter: _PintorMarca(
              avance: _avance.value,
              correcta: widget.correcta,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorMarca extends CustomPainter {
  final double avance;
  final bool correcta;
  final Color color;

  _PintorMarca({
    required this.avance,
    required this.correcta,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final grosor = s * 0.1;
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1.ª mitad: el círculo; 2.ª mitad: el ✓ o la ✗.
    final circulo = (avance * 2).clamp(0.0, 1.0).toDouble();
    final marca = (avance * 2 - 1).clamp(0.0, 1.0).toDouble();
    final rect = (Offset.zero & size).deflate(grosor / 2);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * circulo, false, pincel);
    if (marca == 0) return;

    final trazo = Path();
    if (correcta) {
      trazo
        ..moveTo(s * 0.28, s * 0.52)
        ..lineTo(s * 0.44, s * 0.67)
        ..lineTo(s * 0.72, s * 0.37);
    } else {
      trazo
        ..moveTo(s * 0.34, s * 0.34)
        ..lineTo(s * 0.66, s * 0.66)
        ..moveTo(s * 0.66, s * 0.34)
        ..lineTo(s * 0.34, s * 0.66);
    }
    // Dibuja solo la parte del trazo que va en [marca] (efecto lápiz).
    final total = trazo.computeMetrics().fold<double>(
      0,
      (suma, m) => suma + m.length,
    );
    var falta = total * marca;
    for (final m in trazo.computeMetrics()) {
      if (falta <= 0) break;
      canvas.drawPath(m.extractPath(0, math.min(falta, m.length)), pincel);
      falta -= m.length;
    }
  }

  @override
  bool shouldRepaint(_PintorMarca anterior) =>
      anterior.avance != avance || anterior.correcta != correcta;
}
