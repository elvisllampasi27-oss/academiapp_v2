import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tema_panel.dart';

/// Gráficos del panel dibujados a mano (sin paquetes): curvas suaves con
/// relleno degradado, cuadrícula y detalle al pasar el mouse.

/// Techo "redondo" para el eje Y: 7 -> 8, 23 -> 25, 140 -> 150.
double techoEje(double maximo) {
  if (maximo <= 0) return 4;
  final potencia = math.pow(10, (math.log(maximo) / math.ln10).floor());
  for (final paso in const [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) {
    final techo = paso * potencia;
    if (techo >= maximo) return techo.toDouble();
  }
  return (10 * potencia).toDouble();
}

/// Curva suave que pasa por todos los puntos sin pasarse de ellos
/// (controles a medio camino en X).
Path curvaSuave(List<Offset> puntos) {
  final camino = Path();
  if (puntos.isEmpty) return camino;
  camino.moveTo(puntos.first.dx, puntos.first.dy);
  for (var i = 1; i < puntos.length; i++) {
    final a = puntos[i - 1];
    final b = puntos[i];
    final medio = (b.dx - a.dx) / 2;
    camino.cubicTo(a.dx + medio, a.dy, b.dx - medio, b.dy, b.dx, b.dy);
  }
  return camino;
}

/// Mini gráfica de tendencia para las tarjetas de cifras.
class PintorTendencia extends CustomPainter {
  final List<double> valores;
  final Color color;

  PintorTendencia(this.valores, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final maximo = valores.reduce(math.max);
    final minimo = valores.reduce(math.min);
    final rango = (maximo - minimo) == 0 ? 1 : maximo - minimo;
    final paso = size.width / (valores.length - 1);
    final puntos = [
      for (var i = 0; i < valores.length; i++)
        Offset(
          i * paso,
          size.height - 3 - (valores[i] - minimo) / rango * (size.height - 6),
        ),
    ];
    final linea = curvaSuave(puntos);
    final relleno = Path.from(linea)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      relleno,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0),
        ]),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(PintorTendencia old) =>
      old.color != color || old.valores != valores;
}

class SerieGrafico {
  final String nombre;
  final List<double> valores;
  final Color color;

  /// La serie principal lleva relleno; las demás, solo línea.
  final bool relleno;

  const SerieGrafico({
    required this.nombre,
    required this.valores,
    required this.color,
    this.relleno = false,
  });
}

/// Leyenda: "— Prácticas   — Exámenes".
class LeyendaGrafico extends StatelessWidget {
  final List<SerieGrafico> series;
  const LeyendaGrafico(this.series, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return Wrap(
      spacing: 16,
      children: [
        for (final s in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 3,
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(s.nombre, style: TextStyle(color: p.apagado, fontSize: 13)),
            ],
          ),
      ],
    );
  }
}

/// Gráfico de áreas con detalle al pasar el mouse.
class GraficoArea extends StatefulWidget {
  final List<String> etiquetas;
  final List<SerieGrafico> series;
  final double alto;

  const GraficoArea({
    super.key,
    required this.etiquetas,
    required this.series,
    this.alto = 240,
  });

  @override
  State<GraficoArea> createState() => _GraficoAreaState();
}

class _GraficoAreaState extends State<GraficoArea> {
  static const _margenIzquierdo = 40.0;
  static const _margenInferior = 26.0;
  static const _margenSuperior = 10.0;

  int? _indice;

  int? _indiceEn(double x, double ancho) {
    final n = widget.etiquetas.length;
    if (n < 2) return null;
    final util = ancho - _margenIzquierdo - 8;
    final i = ((x - _margenIzquierdo) / util * (n - 1)).round();
    return i.clamp(0, n - 1).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return SizedBox(
      height: widget.alto,
      child: LayoutBuilder(
        builder: (context, c) {
          final pintor = _PintorArea(
            etiquetas: widget.etiquetas,
            series: widget.series,
            indice: _indice,
            colorTexto: p.tenue,
            colorFondo: p.fondo,
            margenIzquierdo: _margenIzquierdo,
            margenInferior: _margenInferior,
            margenSuperior: _margenSuperior,
          );
          final i = _indice;
          return MouseRegion(
            onHover: (e) => setState(
              () => _indice = _indiceEn(e.localPosition.dx, c.maxWidth),
            ),
            onExit: (_) => setState(() => _indice = null),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // El gráfico se "dibuja" de izquierda a derecha al aparecer.
                Positioned.fill(
                  child: Revelar(child: CustomPaint(painter: pintor)),
                ),
                if (i != null)
                  Positioned(
                    top: 0,
                    left: (pintor.xDe(i, c.maxWidth) + 12)
                        .clamp(0, math.max(0, c.maxWidth - 170))
                        .toDouble(),
                    child: IgnorePointer(child: _detalle(p, i)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detalle(PaletaPanel p, int i) {
    return Container(
      width: 158,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.dialogo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PaletaPanel.bordeFuerte),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.etiquetas[i],
            style: TextStyle(color: p.tenue, fontSize: 11),
          ),
          const SizedBox(height: 4),
          for (final s in widget.series)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.nombre,
                      style: TextStyle(color: p.apagado, fontSize: 12),
                    ),
                  ),
                  Text(
                    s.valores[i].round().toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PintorArea extends CustomPainter {
  final List<String> etiquetas;
  final List<SerieGrafico> series;
  final int? indice;
  final Color colorTexto;
  final Color colorFondo;
  final double margenIzquierdo;
  final double margenInferior;
  final double margenSuperior;

  _PintorArea({
    required this.etiquetas,
    required this.series,
    required this.indice,
    required this.colorTexto,
    required this.colorFondo,
    required this.margenIzquierdo,
    required this.margenInferior,
    required this.margenSuperior,
  });

  double xDe(int i, double ancho) {
    final util = ancho - margenIzquierdo - 8;
    return margenIzquierdo +
        (etiquetas.length < 2 ? 0 : util * i / (etiquetas.length - 1));
  }

  void _texto(
    Canvas canvas,
    String texto,
    Offset posicion, {
    TextAlign alineacion = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(color: colorTexto, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (alineacion) {
      TextAlign.right => posicion.dx - tp.width,
      TextAlign.center => posicion.dx - tp.width / 2,
      _ => posicion.dx,
    };
    tp.paint(canvas, Offset(dx, posicion.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = etiquetas.length;
    if (n == 0) return;

    final maximo = techoEje(
      series.expand((s) => s.valores).fold<double>(0, (m, v) => v > m ? v : m),
    );
    final abajo = size.height - margenInferior;
    final alto = abajo - margenSuperior;
    double yDe(double v) => abajo - v / maximo * alto;

    // Cuadrícula y valores del eje Y.
    final rejilla = Paint()
      ..color = const Color(0x12FFFFFF)
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final valor = maximo * k / 4;
      final y = yDe(valor);
      canvas.drawLine(
        Offset(margenIzquierdo, y),
        Offset(size.width, y),
        rejilla,
      );
      _texto(
        canvas,
        valor % 1 == 0 ? valor.toInt().toString() : valor.toStringAsFixed(1),
        Offset(margenIzquierdo - 10, y),
        alineacion: TextAlign.right,
      );
    }

    // Etiquetas del eje X sin amontonarse.
    final cada = math.max(1, (n / math.max(1, size.width / 72)).ceil());
    for (var i = 0; i < n; i += cada) {
      _texto(
        canvas,
        etiquetas[i],
        Offset(xDe(i, size.width), abajo + margenInferior / 2 + 2),
        alineacion: TextAlign.center,
      );
    }

    // Línea vertical del punto señalado.
    final i = indice;
    if (i != null) {
      final x = xDe(i, size.width);
      final guia = Paint()
        ..color = const Color(0x33FFFFFF)
        ..strokeWidth = 1;
      for (var y = margenSuperior; y < abajo; y += 8) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 4, abajo)), guia);
      }
    }

    // Series: primero las de relleno, encima las líneas.
    final ordenadas = [
      ...series.where((s) => s.relleno),
      ...series.where((s) => !s.relleno),
    ];
    for (final s in ordenadas) {
      if (s.valores.length != n) continue;
      final puntos = [
        for (var k = 0; k < n; k++)
          Offset(xDe(k, size.width), yDe(s.valores[k])),
      ];
      final linea = curvaSuave(puntos);

      if (s.relleno) {
        final area = Path.from(linea)
          ..lineTo(puntos.last.dx, abajo)
          ..lineTo(puntos.first.dx, abajo)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, margenSuperior),
              Offset(0, abajo),
              [s.color.withValues(alpha: 0.32), s.color.withValues(alpha: 0)],
            ),
        );
      }

      canvas.drawPath(
        linea,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      if (i != null) {
        canvas.drawCircle(puntos[i], 5.5, Paint()..color = colorFondo);
        canvas.drawCircle(
          puntos[i],
          5.5,
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorArea old) =>
      old.indice != indice ||
      old.series != series ||
      old.etiquetas != etiquetas ||
      old.colorTexto != colorTexto;
}

/// Avance en forma de anillo con el porcentaje al centro (ocupa poco y se
/// lee de un vistazo).
class AnilloAvance extends StatelessWidget {
  final double valor;
  final double tamano;
  final double grosor;
  final Color? color;

  const AnilloAvance(
    this.valor, {
    super.key,
    this.tamano = 40,
    this.grosor = 4,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    // Se llena desde cero al aparecer (y se mueve suave si cambia).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor.clamp(0.0, 1.0).toDouble()),
      duration: duracionAnimacion(context, const Duration(milliseconds: 1200)),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox.square(
        dimension: tamano,
        child: CustomPaint(
          painter: _PintorAnillo(v, color ?? p.acento, grosor),
          child: Center(
            child: Text(
              '${(v * 100).round()}%',
              style: TextStyle(
                fontSize: tamano * 0.26,
                fontWeight: FontWeight.w700,
                color: p.texto,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorAnillo extends CustomPainter {
  final double valor;
  final Color color;
  final double grosor;

  _PintorAnillo(this.valor, this.color, this.grosor);

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(grosor / 2, grosor / 2) &
        Size(size.width - grosor, size.height - grosor);
    final base = Paint()
      ..color = PaletaPanel.borde
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    canvas.drawArc(rect, 0, 2 * math.pi, false, base);
    if (valor <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * valor,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PintorAnillo old) =>
      old.valor != valor || old.color != color || old.grosor != grosor;
}

/// Barras verticales con su valor arriba y su etiqueta abajo. La última
/// (el periodo actual) va resaltada.
class GraficoBarras extends StatelessWidget {
  final List<String> etiquetas;
  final List<int> valores;
  final double alto;

  /// Cómo se escribe el valor sobre la barra (por defecto, el número).
  final String Function(int valor)? formato;

  const GraficoBarras({
    super.key,
    required this.etiquetas,
    required this.valores,
    this.alto = 200,
    this.formato,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final maximo = valores.fold(1, (m, v) => v > m ? v : m);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracionAnimacion(context, const Duration(milliseconds: 1100)),
      curve: Curves.easeOutCubic,
      builder: (context, crece, _) => SizedBox(
        height: alto,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, valor) in valores.indexed)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      formato?.call(valor) ?? '$valor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.apagado, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    // La barra usa el alto que queda: nunca se desborda.
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: valor <= 0
                              ? 0.03
                              : math.max(0.03, valor / maximo * crece),
                          child: Container(
                            width: 36,
                            decoration: BoxDecoration(
                              color: i == valores.length - 1
                                  ? p.acento
                                  : PaletaPanel.bordeFuerte,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                                bottom: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      i < etiquetas.length ? etiquetas[i] : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.apagado, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Duración de una animación, o cero si el sistema pide reducirlas.
Duration duracionAnimacion(BuildContext context, Duration normal) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
    ? Duration.zero
    : normal;

/// Muestra su contenido de izquierda a derecha, una vez, al aparecer.
class Revelar extends StatelessWidget {
  final Widget child;

  const Revelar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracionAnimacion(context, const Duration(milliseconds: 1500)),
      curve: Curves.easeInOutCubic,
      child: child,
      builder: (context, t, hijo) =>
          ClipRect(clipper: _RecorteIzquierda(t), child: hijo),
    );
  }
}

class _RecorteIzquierda extends CustomClipper<Rect> {
  final double t;

  _RecorteIzquierda(this.t);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * t, size.height);

  @override
  bool shouldReclip(_RecorteIzquierda anterior) => anterior.t != t;
}
