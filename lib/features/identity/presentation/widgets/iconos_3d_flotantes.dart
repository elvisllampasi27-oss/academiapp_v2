import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Íconos 3D que flotan despacio detrás del texto de la bienvenida. Lee los
/// PNG de `assets/3d/`; si falta alguno, ese simplemente no aparece. Con
/// "reducir animaciones" quedan quietos.
class Iconos3DFlotantes extends StatefulWidget {
  const Iconos3DFlotantes({super.key});

  /// Archivo, posición (0 a 1 en ancho y alto), tamaño y desfase del vaivén.
  static const iconos = [
    ('assets/3d/libro.png', Offset(0.80, 0.13), 116.0, 0.0),
    ('assets/3d/trofeo.png', Offset(0.16, 0.24), 82.0, 0.35),
    ('assets/3d/foco.png', Offset(0.60, 0.31), 66.0, 0.7),
    ('assets/3d/calculadora.png', Offset(0.92, 0.40), 72.0, 0.15),
  ];

  @override
  State<Iconos3DFlotantes> createState() => _Iconos3DFlotantesState();
}

class _Iconos3DFlotantesState extends State<Iconos3DFlotantes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vaiven = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  /// Solo los íconos cuyo PNG está en el proyecto (sin imágenes, nada se
  /// dibuja ni se anima).
  List<(String, Offset, double, double)> _presentes = const [];
  bool _revisado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_revisado) {
      _revisado = true;
      AssetManifest.loadFromAssetBundle(DefaultAssetBundle.of(context))
          .then((manifiesto) {
            final hay = manifiesto.listAssets().toSet();
            if (!mounted) return;
            setState(() {
              _presentes = [
                for (final i in Iconos3DFlotantes.iconos)
                  if (hay.contains(i.$1)) i,
              ];
            });
            _animar();
          })
          .catchError((Object _) {});
    }
    _animar();
  }

  void _animar() {
    if (_presentes.isEmpty ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _vaiven.stop();
    } else if (!_vaiven.isAnimating) {
      _vaiven.repeat();
    }
  }

  @override
  void dispose() {
    _vaiven.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_presentes.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) => AnimatedBuilder(
          animation: _vaiven,
          builder: (context, _) => Stack(
            children: [
              for (final (archivo, posicion, tamano, desfase) in _presentes)
                _icono(c, archivo, posicion, tamano, desfase),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icono(
    BoxConstraints c,
    String archivo,
    Offset posicion,
    double tamano,
    double desfase,
  ) {
    final fase = (_vaiven.value + desfase) * 2 * math.pi;
    return Positioned(
      left: c.maxWidth * posicion.dx - tamano / 2,
      top: c.maxHeight * posicion.dy - tamano / 2 + math.sin(fase) * 10,
      child: Transform.rotate(
        angle: math.sin(fase + 1) * 0.06,
        child: Opacity(
          opacity: 0.92,
          child: Image.asset(
            archivo,
            width: tamano,
            height: tamano,
            fit: BoxFit.contain,
            errorBuilder: (context, error, pila) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
