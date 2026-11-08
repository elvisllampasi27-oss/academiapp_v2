import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'animaciones.dart' show sinAnimaciones;

/// Gestos del puma tutor.
enum GestoPuma {
  /// Atento, mirando al alumno (parpadea de vez en cuando).
  atento,

  /// Mirada hacia arriba: está revisando o pensando la respuesta.
  pensando,

  /// Contento: acertó o le fue bien.
  contento,

  /// Ánimo ante un error: ojos cerrados, cabeza inclinada y sonrisa suave
  /// con la boca cerrada ("tranquilo, ya lo vas a lograr"). Nunca burlón.
  animo,

  /// Serio: una corrección importante, con calma.
  serio,
}

/// El puma tutor de AcademiApp: un dibujo por gesto (sin fondo, todos con
/// el mismo encuadre) que cambia con un fundido corto. Atento, parpadea cada
/// pocos segundos. Al hablar, solo se mueve la mandíbula (sobre el dibujo
/// "atento") y la cabeza acompaña apenas: nada de cambiar el dibujo entero.
class PumaTutor extends StatefulWidget {
  final GestoPuma gesto;
  final double tamano;

  /// Mientras habla no parpadea y mueve la boca.
  final bool hablando;

  /// Cada vez que este número cambia (una palabra dicha), la boca se abre y
  /// se cierra suave.
  final int silabas;

  const PumaTutor({
    super.key,
    this.gesto = GestoPuma.atento,
    this.tamano = 120,
    this.hablando = false,
    this.silabas = 0,
  });

  static String rutaDe(GestoPuma gesto) =>
      'assets/puma/tutor/${switch (gesto) {
        GestoPuma.atento => 'atento',
        GestoPuma.pensando => 'pensando',
        GestoPuma.contento => 'contento',
        GestoPuma.animo => 'animo',
        GestoPuma.serio => 'serio',
      }}.webp';

  static const _rutaParpadeo = 'assets/puma/tutor/parpadeo.webp';

  @override
  State<PumaTutor> createState() => _PumaTutorState();
}

class _PumaTutorState extends State<PumaTutor>
    with SingleTickerProviderStateMixin {
  static const _cadaParpadeo = Duration(seconds: 5);
  static const _duracionParpadeo = Duration(milliseconds: 150);

  Timer? _parpadeos;
  Timer? _finParpadeo;
  bool _parpadeando = false;
  bool _precargado = false;

  /// Apertura de la boca: 0 cerrada, 1 abierta.
  late final AnimationController _boca = AnimationController(vsync: this);

  /// El dibujo "atento" para recortar la mandíbula.
  ImageStream? _flujo;
  ImageInfo? _atento;
  late final ImageStreamListener _oyente = ImageStreamListener((info, _) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _atento?.dispose();
      _atento = info;
    });
  }, onError: (_, _) {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Todos los gestos listos de antemano: al cambiar no hay un hueco.
    if (!_precargado) {
      _precargado = true;
      for (final ruta in {
        for (final g in GestoPuma.values) PumaTutor.rutaDe(g),
        PumaTutor._rutaParpadeo,
      }) {
        precacheImage(AssetImage(ruta), context, onError: (_, _) {});
      }
    }
    final flujo = AssetImage(PumaTutor.rutaDe(GestoPuma.atento))
        .resolve(createLocalImageConfiguration(context));
    if (flujo.key != _flujo?.key) {
      _flujo?.removeListener(_oyente);
      _flujo = flujo..addListener(_oyente);
    }
    _programarParpadeo();
  }

  @override
  void didUpdateWidget(PumaTutor anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.gesto != widget.gesto ||
        anterior.hablando != widget.hablando) {
      _programarParpadeo();
    }
    if (!widget.hablando) {
      _boca.animateTo(0, duration: const Duration(milliseconds: 120));
    } else if (widget.silabas != anterior.silabas && !sinAnimaciones(context)) {
      _abrirBoca();
    }
  }

  /// Abre rápido y cierra un poco más lento, como al pronunciar. Si llega
  /// otra palabra antes de cerrar, sigue desde donde va (sin saltos).
  void _abrirBoca() {
    _boca
        .animateTo(
          1,
          duration: const Duration(milliseconds: 85),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (mounted) {
            _boca.animateTo(
              0,
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeInOut,
            );
          }
        });
  }

  /// Solo parpadea atento y con las animaciones permitidas.
  void _programarParpadeo() {
    final debe =
        widget.gesto == GestoPuma.atento &&
        !widget.hablando &&
        !sinAnimaciones(context);
    if (!debe) {
      _parpadeos?.cancel();
      _parpadeos = null;
      _finParpadeo?.cancel();
      _parpadeando = false;
      return;
    }
    _parpadeos ??= Timer.periodic(_cadaParpadeo, (_) {
      if (!mounted) return;
      setState(() => _parpadeando = true);
      _finParpadeo?.cancel();
      _finParpadeo = Timer(_duracionParpadeo, () {
        if (mounted) setState(() => _parpadeando = false);
      });
    });
  }

  @override
  void dispose() {
    _parpadeos?.cancel();
    _finParpadeo?.cancel();
    _flujo?.removeListener(_oyente);
    _atento?.dispose();
    _boca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Al hablar se parte del dibujo "atento": la mandíbula se recorta de él.
    final ruta = widget.hablando
        ? PumaTutor.rutaDe(GestoPuma.atento)
        : _parpadeando && widget.gesto == GestoPuma.atento
        ? PumaTutor._rutaParpadeo
        : PumaTutor.rutaDe(widget.gesto);

    return Semantics(
      image: true,
      label: widget.hablando
          ? 'Puma tutor hablando'
          : 'Puma tutor ${widget.gesto.name}',
      child: SizedBox.square(
        dimension: widget.tamano,
        child: AnimatedBuilder(
          animation: _boca,
          builder: (context, hijo) {
            final a = _boca.value;
            // La cabeza acompaña apenas cada sílaba.
            return Transform.translate(
              offset: Offset(0, -widget.tamano * 0.006 * a),
              child: Transform.scale(
                scale: 1 + 0.012 * a,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hijo!,
                    CustomPaint(
                      painter: _Mandibula(
                        imagen: widget.hablando ? _atento?.image : null,
                        apertura: a,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: AnimatedSwitcher(
            // El parpadeo es instantáneo; los cambios de gesto, un fundido.
            duration: _parpadeando || sinAnimaciones(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            child: Image(
              key: ValueKey(ruta),
              image: AssetImage(ruta),
              width: widget.tamano,
              height: widget.tamano,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja la boca abierta sobre el puma "atento": el interior oscuro (en
/// forma de lente: abierta al centro, cerrada en las comisuras) y el mentón
/// recortado del mismo dibujo, que baja más al centro que a los lados.
/// Coordenadas en píxeles de la imagen (360 × 360).
class _Mandibula extends CustomPainter {
  final ui.Image? imagen;
  final double apertura;

  _Mandibula({required this.imagen, required this.apertura});

  /// Línea entre los labios, de comisura a comisura.
  static const _labios = [
    Offset(194, 214),
    Offset(206, 217),
    Offset(220, 219.5),
    Offset(242, 221),
    Offset(262, 218.5),
    Offset(274, 213),
  ];

  /// Contorno del mentón (desde la comisura derecha, por abajo, a la izquierda).
  static const _menton = [
    Offset(273, 226),
    Offset(266, 238),
    Offset(254, 247),
    Offset(242, 250),
    Offset(228, 248),
    Offset(214, 240),
    Offset(200, 228),
  ];

  static const _centro = 236.0;
  static const _medioAncho = 40.0;

  /// Cuánto baja el mentón al abrir del todo (píxeles de la imagen).
  static const _caida = 10.0;

  /// Qué tanto se abre en cada [x]: 1 al centro, 0 en las comisuras.
  static double _peso(double x) =>
      math.max(0.0, 1 - math.pow((x - _centro) / _medioAncho, 2).toDouble());

  static double _labioEn(double x) {
    for (var i = 0; i < _labios.length - 1; i++) {
      final a = _labios[i];
      final b = _labios[i + 1];
      if (x <= b.dx) {
        final t = ((x - a.dx) / (b.dx - a.dx)).clamp(0.0, 1.0);
        return a.dy + (b.dy - a.dy) * t;
      }
    }
    return _labios.last.dy;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final imagen = this.imagen;
    if (imagen == null || apertura < 0.02) return;
    final caida = _caida * apertura;

    canvas.save();
    canvas.scale(size.width / imagen.width, size.height / imagen.height);

    // Interior de la boca.
    final hueco = Path()..moveTo(_labios.first.dx, _labios.first.dy);
    final xs = [for (var x = _labios.first.dx; x <= _labios.last.dx; x += 2) x];
    for (final x in xs) {
      hueco.lineTo(x, _labioEn(x));
    }
    for (final x in xs.reversed) {
      hueco.lineTo(x, _labioEn(x) + caida * _peso(x));
    }
    hueco.close();
    canvas.drawPath(hueco, Paint()..color = const Color(0xFF240E10));
    // Lengua, apenas visible al abrir más.
    if (apertura > 0.35) {
      canvas.save();
      canvas.clipPath(hueco);
      canvas.drawOval(
        Rect.fromLTRB(
          _centro - 11,
          221 + caida * 0.55,
          _centro + 11,
          221 + caida + 2,
        ),
        Paint()
          ..color = const Color(
            0xFF69282E,
          ).withValues(alpha: ((apertura - 0.35) / 0.65 * 0.8).clamp(0.0, 1.0)),
      );
      canvas.restore();
    }

    // Mentón: en franjas verticales, cada una baja según su peso.
    final menton = Path()..addPolygon([..._labios, ..._menton], true);
    final pintura = Paint()..filterQuality = FilterQuality.medium;
    const franjas = 20;
    final ancho = (_labios.last.dx - _labios.first.dx) / franjas;
    for (var i = 0; i < franjas; i++) {
      final x0 = _labios.first.dx + i * ancho;
      final baja = caida * _peso(x0 + ancho / 2);
      canvas.save();
      // Un pelo más ancha para que no se vean costuras entre franjas.
      canvas.clipRect(Rect.fromLTWH(x0 - 0.3, 150, ancho + 0.6, 140));
      canvas.translate(0, baja);
      canvas.clipPath(menton);
      canvas.drawImage(imagen, Offset.zero, pintura);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Mandibula anterior) =>
      anterior.apertura != apertura || anterior.imagen != imagen;
}
