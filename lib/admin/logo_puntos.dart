import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tema_panel.dart';

/// Logo del panel: una esfera de puntos dorados que gira despacio.
/// Los puntos se reparten con la espiral de Fibonacci; los de adelante se
/// ven más grandes y brillantes. Si el sistema pide reducir animaciones,
/// queda quieta.
class LogoPuntos extends StatefulWidget {
  final double tamano;
  final int puntos;

  const LogoPuntos({super.key, this.tamano = 36, this.puntos = 110});

  @override
  State<LogoPuntos> createState() => _LogoPuntosState();
}

class _LogoPuntosState extends State<LogoPuntos>
    with SingleTickerProviderStateMixin {
  late final _giro = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quieto = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (quieto) {
      _giro.stop();
    } else if (!_giro.isAnimating) {
      _giro.repeat();
    }
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.tamano,
        child: CustomPaint(
          painter: _PintorEsfera(
            giro: _giro,
            puntos: widget.puntos,
            atras: p.dorado.last,
            adelante: p.dorado.first,
          ),
        ),
      ),
    );
  }
}

class _PintorEsfera extends CustomPainter {
  final Animation<double> giro;
  final int puntos;
  final Color atras;
  final Color adelante;

  _PintorEsfera({
    required this.giro,
    required this.puntos,
    required this.atras,
    required this.adelante,
  }) : super(repaint: giro);

  static final _anguloDorado = math.pi * (3 - math.sqrt(5));
  static const _inclinacion = 0.38;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.shortestSide / 2 - 1.5;
    final angulo = giro.value * 2 * math.pi;
    final cosA = math.cos(angulo), senA = math.sin(angulo);
    final cosI = math.cos(_inclinacion), senI = math.sin(_inclinacion);

    final proyectados = <(double, Offset)>[];
    for (var i = 0; i < puntos; i++) {
      final y = 1 - 2 * i / (puntos - 1);
      final r = math.sqrt(math.max(0, 1 - y * y));
      final theta = _anguloDorado * i;
      final x = math.cos(theta) * r;
      final z = math.sin(theta) * r;

      // Giro sobre el eje vertical y una leve inclinación hacia el frente.
      final x1 = x * cosA + z * senA;
      final z1 = -x * senA + z * cosA;
      final y2 = y * cosI - z1 * senI;
      final z2 = y * senI + z1 * cosI;

      proyectados.add((z2, centro + Offset(x1 * radio, y2 * radio)));
    }

    // Primero los de atrás, para que los de adelante queden encima.
    proyectados.sort((a, b) => a.$1.compareTo(b.$1));
    final pincel = Paint();
    for (final (profundidad, posicion) in proyectados) {
      final t = (profundidad + 1) / 2; // 0 atrás, 1 adelante
      pincel.color = Color.lerp(
        atras,
        adelante,
        t,
      )!.withValues(alpha: 0.18 + 0.82 * t);
      canvas.drawCircle(
        posicion,
        size.shortestSide * (0.012 + 0.028 * t),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorEsfera old) =>
      old.puntos != puntos || old.atras != atras || old.adelante != adelante;
}
