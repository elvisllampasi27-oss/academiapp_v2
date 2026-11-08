import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'animaciones.dart' show sinAnimaciones;
import 'colores_app.dart';

/// Indicador de carga de AcademiApp: en vez de un círculo que gira, el puma
/// se va formando. Primero aparecen sus líneas celestes desde los ojos hacia
/// afuera y luego se rellenan las caras low poly.
///
/// - [progreso] (0 a 1) es el avance real, si se conoce. Si no, la figura
///   avanza sola cada vez más lento, sin pasar de 94 %.
/// - Solo con [lista] se completa del todo y llama a [alCompletar] una vez.
/// - [avanceCompartido] permite que varias pantallas seguidas (el arranque)
///   continúen la misma figura en vez de empezar de cero cada una.
///
/// Las imágenes no tienen fondo: el fondo lo pone la pantalla. Si no se
/// pueden cargar, la carga sigue funcionando (solo no se ve la figura).
class CargaPuma extends StatefulWidget {
  final double? progreso;
  final bool lista;
  final VoidCallback? alCompletar;
  final double tamano;
  final String? etiqueta;

  /// Si la [etiqueta] se muestra debajo (si no, solo la leen los lectores
  /// de pantalla).
  final bool mostrarEtiqueta;
  final ValueNotifier<double>? avanceCompartido;

  /// Espera antes de mostrarse: si la carga es más corta, no aparece (evita
  /// un parpadeo en cargas rápidas).
  final Duration retrasoAparicion;

  const CargaPuma({
    super.key,
    this.progreso,
    this.lista = false,
    this.alCompletar,
    this.tamano = 220,
    this.etiqueta,
    this.mostrarEtiqueta = true,
    this.avanceCompartido,
    this.retrasoAparicion = Duration.zero,
  });

  /// Versión chica para las cargas dentro de las pantallas (reemplaza al
  /// círculo). No se completa: la pantalla la cambia por su contenido.
  const CargaPuma.compacta({super.key})
    : progreso = null,
      lista = false,
      alCompletar = null,
      tamano = 84,
      etiqueta = null,
      mostrarEtiqueta = false,
      avanceCompartido = null,
      retrasoAparicion = const Duration(milliseconds: 300);

  /// Tope mientras la app no está lista.
  static const tope = 0.94;

  @override
  State<CargaPuma> createState() => _CargaPumaState();
}

class _CargaPumaState extends State<CargaPuma> with TickerProviderStateMixin {
  static const _rutaRostro = 'assets/puma/rostro.webp';
  static const _rutaLineas = 'assets/puma/lineas.webp';

  /// Proporción de las imágenes (ancho / alto).
  static const _proporcion = 659 / 624;

  /// Tiempo en que avanza sola (sin progreso real) antes de quedarse quieta.
  static const _duracionSola = Duration(seconds: 7);

  late final AnimationController _sola = AnimationController(
    vsync: this,
    duration: _duracionSola,
  );
  late final AnimationController _final = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  /// Desde dónde arrancó esta figura (continúa la del arranque si hay).
  late final double _inicio = (widget.avanceCompartido?.value ?? 0)
      .clamp(0, CargaPuma.tope)
      .toDouble();

  /// Avance mostrado justo cuando llegó la señal de "lista".
  double _alListo = 0;
  bool _avisado = false;

  ImageStream? _flujoRostro;
  ImageStream? _flujoLineas;
  ImageInfo? _rostro;
  ImageInfo? _lineas;
  late final ImageStreamListener _oyenteRostro = ImageStreamListener(
    (info, _) => _poner(() {
      _rostro?.dispose();
      _rostro = info;
    }),
    onError: (_, _) {},
  );
  late final ImageStreamListener _oyenteLineas = ImageStreamListener(
    (info, _) => _poner(() {
      _lineas?.dispose();
      _lineas = info;
    }),
    onError: (_, _) {},
  );

  void _poner(VoidCallback cambio) {
    if (mounted) setState(cambio);
  }

  @override
  void initState() {
    super.initState();
    _final.addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _avisarCompleto();
    });
    // Se guarda en cada paso: la pantalla siguiente del arranque se crea
    // antes de que esta se cierre y debe leer el avance ya actualizado.
    if (widget.avanceCompartido != null) _sola.addListener(_compartir);
  }

  void _compartir() {
    if (!_avisado) widget.avanceCompartido?.value = _avanceMientrasCarga;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final configuracion = createLocalImageConfiguration(context);
    final rostro = const AssetImage(_rutaRostro).resolve(configuracion);
    if (rostro.key != _flujoRostro?.key) {
      _flujoRostro?.removeListener(_oyenteRostro);
      _flujoRostro = rostro..addListener(_oyenteRostro);
    }
    final lineas = const AssetImage(_rutaLineas).resolve(configuracion);
    if (lineas.key != _flujoLineas?.key) {
      _flujoLineas?.removeListener(_oyenteLineas);
      _flujoLineas = lineas..addListener(_oyenteLineas);
    }

    if (sinAnimaciones(context)) {
      _sola.value = 1;
      if (widget.lista) _completar();
    } else if (!_sola.isAnimating && !_sola.isCompleted) {
      _sola.forward();
      if (widget.lista) _completar();
    }
  }

  @override
  void didUpdateWidget(CargaPuma anterior) {
    super.didUpdateWidget(anterior);
    if (widget.lista && !anterior.lista) _completar();
  }

  void _completar() {
    if (_final.isAnimating || _final.isCompleted) return;
    _alListo = _avanceMientrasCarga;
    if (sinAnimaciones(context)) {
      _final.value = 1;
      _avisarCompleto();
    } else {
      _final.forward();
    }
  }

  void _avisarCompleto() {
    if (_avisado) return;
    _avisado = true;
    widget.avanceCompartido?.value = 0; // la próxima carga empieza de cero
    // Fuera del cuadro en curso: quien escucha suele cambiar de pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.alCompletar?.call();
    });
  }

  /// Avance sin la señal de "lista": el real si se conoce, si no uno que
  /// crece solo y cada vez más lento. Nunca pasa del tope.
  double get _avanceMientrasCarga {
    final solo =
        _inicio + (CargaPuma.tope - _inicio) * (1 - math.exp(-3 * _sola.value));
    final real = (widget.progreso ?? 0).clamp(0, CargaPuma.tope).toDouble();
    return math.max(solo, real);
  }

  double get _avance {
    if (sinAnimaciones(context)) return 1;
    if (_final.value > 0) {
      final t = Curves.easeOutCubic.transform(_final.value);
      return _alListo + (1 - _alListo) * t;
    }
    return _avanceMientrasCarga;
  }

  @override
  void dispose() {
    _flujoRostro?.removeListener(_oyenteRostro);
    _flujoLineas?.removeListener(_oyenteLineas);
    _rostro?.dispose();
    _lineas?.dispose();
    _sola.dispose();
    _final.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alto = widget.tamano / _proporcion;
    final esperaHasta =
        widget.retrasoAparicion.inMicroseconds / _duracionSola.inMicroseconds;

    final figura = AnimatedBuilder(
      animation: Listenable.merge([_sola, _final]),
      builder: (context, _) {
        // En cargas muy cortas no llega a aparecer.
        final visible = _sola.value >= esperaHasta || _final.value > 0;
        return Opacity(
          opacity: visible ? 1 : 0,
          child: CustomPaint(
            size: Size(widget.tamano, alto),
            painter: _PumaQueSeForma(
              rostro: _rostro?.image,
              lineas: _lineas?.image,
              avance: _avance,
            ),
          ),
        );
      },
    );

    return Semantics(
      liveRegion: true,
      label: widget.etiqueta ?? 'Cargando',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(child: figura),
          if (widget.etiqueta case final etiqueta?
              when widget.mostrarEtiqueta) ...[
            const SizedBox(height: 18),
            Text(
              etiqueta,
              style: const TextStyle(
                color: ColoresApp.apagado,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dibuja las dos capas reveladas desde el centro de los ojos hacia afuera:
/// primero las líneas, después el rostro encima.
class _PumaQueSeForma extends CustomPainter {
  final ui.Image? rostro;
  final ui.Image? lineas;
  final double avance;

  _PumaQueSeForma({
    required this.rostro,
    required this.lineas,
    required this.avance,
  });

  /// Ancho del borde suave del revelado (fracción del radio).
  static const _borde = 0.18;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (avance >= 0.999) {
      // Completo: la imagen tal cual, sin capas extra.
      if (rostro case final imagen?) _dibujar(canvas, rect, imagen);
      return;
    }

    final centro = Offset(size.width * 0.5, size.height * 0.45);
    final radio = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ].map((esquina) => (esquina - centro).distance).reduce(math.max);

    // Las líneas van por delante; el rostro las sigue.
    if (lineas case final imagen?) {
      _revelar(canvas, rect, centro, radio, imagen, avance * 1.6);
    }
    if (rostro case final imagen?) {
      _revelar(canvas, rect, centro, radio, imagen, (avance - 0.3) / 0.7);
    }
  }

  void _revelar(
    Canvas canvas,
    Rect rect,
    Offset centro,
    double radio,
    ui.Image imagen,
    double hasta,
  ) {
    if (hasta <= 0) return;
    final fin = hasta.clamp(0.0, 1.0);
    final inicio = (fin - _borde).clamp(0.0, 1.0);
    canvas.saveLayer(rect, Paint());
    _dibujar(canvas, rect, imagen);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          centro,
          radio,
          const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          [0, inicio, fin, 1],
        ),
    );
    canvas.restore();
  }

  void _dibujar(Canvas canvas, Rect rect, ui.Image imagen) {
    paintImage(
      canvas: canvas,
      rect: rect,
      image: imagen,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_PumaQueSeForma anterior) =>
      anterior.avance != avance ||
      anterior.rostro != rostro ||
      anterior.lineas != lineas;
}
