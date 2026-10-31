import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'colores_app.dart';

class AccionGota {
  final String etiqueta;
  final IconData icono;
  final VoidCallback alPresionar;

  const AccionGota({
    required this.etiqueta,
    required this.icono,
    required this.alPresionar,
  });
}

/// Botón "+" flotante cuyas opciones salen como gotas (efecto gooey).
///
/// El efecto se dibuja con un "cuello" entre círculos en lugar de un
/// desenfoque, así es liviano en celulares de gama baja.
/// Debe ocupar toda la pantalla (Positioned.fill): las zonas vacías dejan
/// pasar los toques.
class MenuGota extends StatefulWidget {
  final List<AccionGota> acciones;

  const MenuGota({super.key, required this.acciones});

  @override
  State<MenuGota> createState() => _MenuGotaState();
}

class _MenuGotaState extends State<MenuGota>
    with SingleTickerProviderStateMixin {
  static const _radioBoton = 30.0;
  static const _radioGota = 24.0;
  static const _paso = 78.0;
  static const _ancho = 260.0;

  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  bool get _abierto =>
      _animacion.status == AnimationStatus.forward ||
      _animacion.status == AnimationStatus.completed;

  void _alternar() => _abierto ? _animacion.reverse() : _animacion.forward();

  void _elegir(AccionGota accion) {
    _animacion.reverse();
    accion.alPresionar();
  }

  /// Avance (con rebote) de la gota [i]: salen escalonadas.
  double _avanceGota(int i, double t) =>
      Interval(i * 0.12, 1, curve: Curves.easeOutBack).transform(t);

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inferior = MediaQuery.paddingOf(context).bottom + 20;
    final alto = _radioBoton * 2 + _paso * widget.acciones.length + 12;

    return AnimatedBuilder(
      animation: _animacion,
      builder: (context, _) {
        final t = _animacion.value;
        final avances = [
          for (var i = 0; i < widget.acciones.length; i++) _avanceGota(i, t),
        ];
        // Centro de cada gota medido desde abajo de la caja.
        final centros = [
          for (var i = 0; i < avances.length; i++)
            _radioBoton + _paso * (i + 1) * avances[i],
        ];

        return Stack(
          children: [
            if (t > 0)
              Positioned.fill(
                // Sin esto, en la web el video (iframe) recibe el toque.
                child: PointerInterceptor(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _animacion.reverse,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45 * t),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 20,
              bottom: inferior,
              width: _ancho,
              height: alto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _PintorGotas(
                          centros: centros,
                          escalas: [
                            for (final a in avances)
                              0.6 + 0.4 * a.clamp(0.0, 1.0),
                          ],
                          radioBoton: _radioBoton,
                          radioGota: _radioGota,
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < widget.acciones.length; i++)
                    ..._opcion(widget.acciones[i], centros[i], avances[i]),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: _radioBoton * 2,
                    height: _radioBoton * 2,
                    child: Semantics(
                      button: true,
                      label: _abierto ? 'Cerrar menú' : 'Abrir menú',
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _alternar,
                          child: Center(
                            child: Transform.rotate(
                              angle: t * math.pi / 4,
                              child: const Icon(
                                Icons.add,
                                size: 30,
                                color: ColoresApp.fondo,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _opcion(AccionGota accion, double centro, double avance) {
    final visible = avance.clamp(0.0, 1.0);
    final activa = visible > 0.5;

    return [
      Positioned(
        right: _radioBoton * 2 + 6,
        bottom: centro - 17,
        child: IgnorePointer(
          ignoring: !activa,
          child: Opacity(
            opacity: visible,
            child: GestureDetector(
              onTap: () => _elegir(accion),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColoresApp.barra,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: ColoresApp.borde),
                ),
                child: Text(
                  accion.etiqueta,
                  style: const TextStyle(
                    color: ColoresApp.texto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: _radioBoton - _radioGota,
        bottom: centro - _radioGota,
        width: _radioGota * 2,
        height: _radioGota * 2,
        child: IgnorePointer(
          ignoring: !activa,
          child: Opacity(
            opacity: visible,
            child: Semantics(
              button: true,
              label: accion.etiqueta,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _elegir(accion),
                  child: Icon(accion.icono, color: ColoresApp.fondo, size: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _PintorGotas extends CustomPainter {
  final List<double> centros;
  final List<double> escalas;
  final double radioBoton;
  final double radioGota;

  _PintorGotas({
    required this.centros,
    required this.escalas,
    required this.radioBoton,
    required this.radioGota,
  });

  /// Distancia entre bordes a la que el cuello se corta.
  static const _corte = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()..color = ColoresApp.texto;
    final x = size.width - radioBoton;
    double y(double desdeAbajo) => size.height - desdeAbajo;

    var yAnterior = y(radioBoton);
    var radioAnterior = radioBoton;

    for (var i = 0; i < centros.length; i++) {
      final yGota = y(centros[i]);
      final radio = radioGota * escalas[i];

      _cuello(canvas, pintura, x, yAnterior, radioAnterior, yGota, radio);
      canvas.drawCircle(Offset(x, yGota), radio, pintura);

      yAnterior = yGota;
      radioAnterior = radio;
    }

    canvas.drawCircle(Offset(x, y(radioBoton)), radioBoton, pintura);
  }

  /// Une dos círculos alineados verticalmente con un cuello que se
  /// adelgaza a medida que se separan, hasta cortarse.
  void _cuello(
    Canvas canvas,
    Paint pintura,
    double x,
    double yAbajo,
    double radioAbajo,
    double yArriba,
    double radioArriba,
  ) {
    final separacion = (yAbajo - yArriba) - radioAbajo - radioArriba;
    if (separacion >= _corte) return;

    final mitadAncho = math.min(radioAbajo, radioArriba) * 0.85;
    final fuerza = separacion <= 0 ? 1.0 : 1 - separacion / _corte;
    // Control de la curva para que el centro del cuello mida
    // mitadAncho * fuerza (0 = se corta en un punto).
    final control = 2 * mitadAncho * fuerza - mitadAncho;
    final medio = (yAbajo + yArriba) / 2;

    final cuello = Path()
      ..moveTo(x - mitadAncho, yAbajo)
      ..quadraticBezierTo(x - control, medio, x - mitadAncho, yArriba)
      ..lineTo(x + mitadAncho, yArriba)
      ..quadraticBezierTo(x + control, medio, x + mitadAncho, yAbajo)
      ..close();

    canvas.drawPath(cuello, pintura);
  }

  @override
  bool shouldRepaint(_PintorGotas anterior) =>
      anterior.centros != centros || anterior.escalas != escalas;
}
