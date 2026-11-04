import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Lluvia de confeti que cae una vez sobre su contenido (no bloquea los
/// toques). Con "reducir animaciones" no se muestra.
class Confeti extends StatefulWidget {
  final bool activo;
  final Widget child;

  const Confeti({super.key, required this.activo, required this.child});

  static const duracion = Duration(milliseconds: 2200);

  @override
  State<Confeti> createState() => _ConfetiState();
}

class _ConfetiState extends State<Confeti> with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: Confeti.duracion,
  );
  final _particulas = <_Particula>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _quizasLanzar();
  }

  @override
  void didUpdateWidget(Confeti anterior) {
    super.didUpdateWidget(anterior);
    if (widget.activo && !anterior.activo) _quizasLanzar();
  }

  void _quizasLanzar() {
    if (!widget.activo || _particulas.isNotEmpty) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    final azar = math.Random();
    const colores = [
      ColoresApp.ambar,
      ColoresApp.celeste,
      ColoresApp.naranja,
      Colors.white,
    ];
    for (var i = 0; i < 70; i++) {
      _particulas.add(
        _Particula(
          x: azar.nextDouble(),
          vx: (azar.nextDouble() - 0.5) * 0.5,
          vy: 0.35 + azar.nextDouble() * 0.5,
          giro: (azar.nextDouble() - 0.5) * 12,
          color: colores[i % colores.length],
          ancho: 5 + azar.nextDouble() * 5,
        ),
      );
    }
    _control.forward(from: 0);
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particulas.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _control,
                builder: (context, _) => _control.isCompleted
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        painter: _PintorConfeti(_particulas, _control.value),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Particula {
  final double x;
  final double vx;
  final double vy;
  final double giro;
  final Color color;
  final double ancho;

  const _Particula({
    required this.x,
    required this.vx,
    required this.vy,
    required this.giro,
    required this.color,
    required this.ancho,
  });
}

class _PintorConfeti extends CustomPainter {
  final List<_Particula> particulas;
  final double t;

  _PintorConfeti(this.particulas, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint();
    // Se desvanece en el último tercio.
    final opacidad = t < 0.66 ? 1.0 : (1 - t) / 0.34;
    for (final p in particulas) {
      // Cae desde arriba con un poco de gravedad y viento.
      final x = (p.x + p.vx * t) * size.width;
      final y = (-0.05 + p.vy * t + 0.6 * t * t) * size.height;
      pincel.color = p.color.withValues(
        alpha: opacidad.clamp(0.0, 1.0).toDouble(),
      );
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.giro * t)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.ancho,
            height: p.ancho * 0.5,
          ),
          pincel,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_PintorConfeti anterior) => anterior.t != t;
}
