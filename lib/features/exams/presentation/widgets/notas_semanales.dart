import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../domain/entities/simulacro.dart';

/// "Tu nota semana a semana": la línea se dibuja sola al entrar (path draw)
/// y cada punto aparece cuando la línea llega a él.
class NotasSemanalesCard extends StatefulWidget {
  final Future<List<NotaSemanal>> Function() cargar;

  const NotasSemanalesCard({super.key, required this.cargar});

  @override
  State<NotasSemanalesCard> createState() => _NotasSemanalesCardState();
}

class _NotasSemanalesCardState extends State<NotasSemanalesCard> {
  late final Future<List<NotaSemanal>> _notas = widget.cargar();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NotaSemanal>>(
      future: _notas,
      builder: (context, s) {
        // Mientras carga o si falla, no ocupa lugar.
        final notas = s.data;
        if (notas == null) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu nota semana a semana',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  notas.isEmpty
                      ? 'Cuando des tu primer examen semanal, aquí verás tu '
                            'avance.'
                      : cambioDeNota(notas) ??
                            'Semana ${notas.last.semana}: ${notas.last.puntaje} %',
                  style: TextStyle(
                    color: switch (cambioDeNota(notas)) {
                      final c? when c.startsWith('↑') => ColoresApp.celeste,
                      final c? when c.startsWith('↓') => ColoresApp.naranja,
                      _ => ColoresApp.apagado,
                    },
                  ),
                ),
                if (notas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GraficoNotas(notas: notas),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class GraficoNotas extends StatefulWidget {
  final List<NotaSemanal> notas;

  const GraficoNotas({super.key, required this.notas});

  @override
  State<GraficoNotas> createState() => _GraficoNotasState();
}

class _GraficoNotasState extends State<GraficoNotas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _trazo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final Animation<double> _avance = CurvedAnimation(
    parent: _trazo,
    curve: Curves.easeInOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trazo.isAnimating || _trazo.isCompleted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _trazo.value = 1;
    } else {
      _trazo.forward();
    }
  }

  @override
  void dispose() {
    _trazo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Notas por semana: '
          '${[for (final n in widget.notas) 'semana ${n.semana}, ${n.puntaje} %'].join('; ')}',
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _avance,
          builder: (context, _) =>
              CustomPaint(painter: _PintorNotas(widget.notas, _avance.value)),
        ),
      ),
    );
  }
}

class _PintorNotas extends CustomPainter {
  final List<NotaSemanal> notas;
  final double t;

  _PintorNotas(this.notas, this.t);

  static const _izq = 30.0;
  static const _der = 12.0;
  static const _arriba = 18.0;
  static const _abajo = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = size.width - _izq - _der;
    final alto = size.height - _arriba - _abajo;
    final etiqueta = TextPainter(textDirection: TextDirection.ltr);

    void texto(String s, Offset centro, {Color color = ColoresApp.apagado}) {
      etiqueta
        ..text = TextSpan(
          text: s,
          style: TextStyle(fontSize: 11, color: color),
        )
        ..layout();
      etiqueta.paint(
        canvas,
        centro - Offset(etiqueta.width / 2, etiqueta.height / 2),
      );
    }

    // Guías de 0, 50 y 100 %.
    final guia = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    for (final v in const [0, 50, 100]) {
      final y = _arriba + alto * (1 - v / 100);
      canvas.drawLine(Offset(_izq, y), Offset(_izq + ancho, y), guia);
      texto('$v', Offset(_izq / 2 - 2, y));
    }

    final n = notas.length;
    Offset punto(int i) => Offset(
      n == 1 ? _izq + ancho / 2 : _izq + ancho * i / (n - 1),
      _arriba + alto * (1 - notas[i].puntaje.clamp(0, 100) / 100),
    );
    final puntos = [for (var i = 0; i < n; i++) punto(i)];

    for (var i = 0; i < n; i++) {
      texto('S${notas[i].semana}', Offset(puntos[i].dx, size.height - 8));
    }

    // Curva suave entre los puntos.
    final camino = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (var i = 1; i < n; i++) {
      final a = puntos[i - 1];
      final b = puntos[i];
      final medio = (a.dx + b.dx) / 2;
      camino.cubicTo(medio, a.dy, medio, b.dy, b.dx, b.dy);
    }

    final linea = Paint()
      ..color = ColoresApp.ambar
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Solo el tramo que ya "dibujó el lápiz".
    for (final m in camino.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), linea);
    }

    // Cada punto aparece cuando la línea lo alcanza.
    final relleno = Paint()..color = ColoresApp.ambar;
    final borde = Paint()..color = ColoresApp.fondo;
    for (var i = 0; i < n; i++) {
      final llega = n == 1 ? 0.0 : i / (n - 1);
      if (t + 0.001 < llega) break;
      final crece = math.min(1.0, (t - llega) * 6 + (n == 1 ? 1 : 0.4));
      canvas
        ..drawCircle(puntos[i], 6 * crece, borde)
        ..drawCircle(puntos[i], 4.5 * crece, relleno);
    }

    // La última nota, cuando terminó de dibujarse.
    if (t >= 1) {
      final ultimo = puntos.last;
      texto(
        '${notas.last.puntaje} %',
        Offset(
          math.min(ultimo.dx, _izq + ancho - 14),
          math.max(ultimo.dy - 14, 8.0),
        ),
        color: ColoresApp.texto,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorNotas anterior) =>
      anterior.t != t || anterior.notas != notas;
}
