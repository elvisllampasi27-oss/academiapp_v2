import 'package:flutter/material.dart';

import '../widgets/estilo_autenticacion.dart';
import '../../../../core/presentation/animaciones.dart';

/// Primera pantalla para quien no ha iniciado sesión.
/// Bienvenida. Al venir del arranque, el puma que se acaba de formar sube,
/// crece y se vuelve tenue hasta quedar de fondo, y entonces bajan a su lugar
/// el título, el texto y el botón de empezar.
class BienvenidaPage extends StatefulWidget {
  final VoidCallback onEmpezar;
  final VoidCallback onCrearCuenta;

  /// Si se llega justo después del puma de carga (anima el paso).
  final bool desdeCarga;

  const BienvenidaPage({
    super.key,
    required this.onEmpezar,
    required this.onCrearCuenta,
    this.desdeCarga = false,
  });

  @override
  State<BienvenidaPage> createState() => _BienvenidaPageState();
}

class _BienvenidaPageState extends State<BienvenidaPage>
    with SingleTickerProviderStateMixin {
  /// Tamaño con que lo deja el puma de carga (CargaArranque.anchoPuma).
  static const _anchoAlCargar = 220.0;

  late final AnimationController _paso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: widget.desdeCarga ? 0 : 1,
  );

  /// El puma va a su lugar de fondo.
  late final Animation<double> _puma = CurvedAnimation(
    parent: _paso,
    curve: const Interval(0, 0.55, curve: Curves.easeInOutCubic),
  );

  /// El botón baja a su lugar.
  late final Animation<double> _boton = CurvedAnimation(
    parent: _paso,
    curve: const Interval(0.5, 0.95, curve: Curves.easeOutBack),
  );
  late final Animation<double> _botonVisible = CurvedAnimation(
    parent: _paso,
    curve: const Interval(0.5, 0.75),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paso.isAnimating || _paso.isCompleted) return;
    if (sinAnimaciones(context)) {
      _paso.value = 1;
    } else {
      _paso.forward();
    }
  }

  @override
  void dispose() {
    _paso.dispose();
    super.dispose();
  }

  /// Los textos esperan a que el puma llegue a su lugar.
  Duration _retraso(int milisegundos) =>
      Duration(milliseconds: milisegundos + (widget.desdeCarga ? 750 : 0));

  @override
  Widget build(BuildContext context) {
    return LetraAcceso(
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, restricciones) => AnimatedBuilder(
                animation: _puma,
                builder: (context, _) =>
                    _pumaEnCamino(restricciones.biggest, _puma.value),
              ),
            ),
            // Más oscuro abajo, donde van las letras.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x40050609),
                    Color(0x1A050609),
                    Color(0xEB050609),
                  ],
                  stops: [0, 0.4, 0.8],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, restricciones) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: restricciones.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              EntradaDifuminada(
                                retraso: _retraso(0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Vidrio(
                                    suave: true,
                                    radio: BorderRadius.circular(20),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: const Text(
                                      'AcademiApp',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 120),
                                  EntradaDifuminada(
                                    retraso: _retraso(0),
                                    duracion: const Duration(milliseconds: 700),
                                    child: const Text(
                                      'Tu ingreso a la UNSCH empieza aquí',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 44,
                                        height: 1.05,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x99000000),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  EntradaDifuminada(
                                    retraso: _retraso(200),
                                    duracion: const Duration(milliseconds: 600),
                                    child: const Text(
                                      'Temas cada día, práctica con corrección '
                                      'al instante y una ruta que se adapta a '
                                      'lo que te falta.',
                                      style: TextStyle(
                                        color: Color(0xFFE4E4E7),
                                        fontSize: 17,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  // El botón baja desde el puma a su lugar.
                                  AnimatedBuilder(
                                    animation: _paso,
                                    builder: (context, hijo) => Opacity(
                                      opacity: _botonVisible.value,
                                      child: Transform.translate(
                                        offset: Offset(
                                          0,
                                          -56 * (1 - _boton.value),
                                        ),
                                        child: hijo,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        DeslizadorEmpezar(
                                          onCompletado: widget.onEmpezar,
                                        ),
                                        const SizedBox(height: 12),
                                        PreguntaConEnlace(
                                          pregunta: '¿Primera vez?',
                                          enlace: 'Crear cuenta',
                                          alPresionar: widget.onCrearCuenta,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
    );
  }

  /// El puma entre donde lo dejó la carga (centro, entero) y su lugar de
  /// fondo (arriba, más grande y tenue). En [t] = 1 queda igual que el
  /// fondo de las demás pantallas de acceso.
  Widget _pumaEnCamino(Size tamano, double t) {
    final desde = Offset(tamano.width / 2, tamano.height / 2);
    final hasta = PumaDeFondo.centroPara(tamano);
    final ancho =
        _anchoAlCargar + (PumaDeFondo.anchoPara(tamano) - _anchoAlCargar) * t;
    final centro = Offset.lerp(desde, hasta, t)!;
    final opacidad = 1 + (PumaDeFondo.opacidad - 1) * t;
    return Stack(
      children: [
        Positioned(
          left: centro.dx - ancho / 2,
          top: centro.dy - ancho / PumaDeFondo.proporcion / 2,
          width: ancho,
          child: Image(
            image: const AssetImage(PumaDeFondo.ruta),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            opacity: AlwaysStoppedAnimation(opacidad),
          ),
        ),
      ],
    );
  }
}

/// "Desliza para empezar": se arrastra el círculo hasta el final.
/// Tocarlo también funciona (accesibilidad y web).
class DeslizadorEmpezar extends StatefulWidget {
  final VoidCallback onCompletado;

  const DeslizadorEmpezar({super.key, required this.onCompletado});

  @override
  State<DeslizadorEmpezar> createState() => _DeslizadorEmpezarState();
}

class _DeslizadorEmpezarState extends State<DeslizadorEmpezar>
    with SingleTickerProviderStateMixin {
  static const _alto = 64.0;
  static const _perilla = 48.0;
  static const _margen = 8.0;

  /// Recorrido del círculo, de 0 a 1.
  late final AnimationController _avance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _avance.dispose();
    super.dispose();
  }

  Future<void> _completar() async {
    await _avance.animateTo(1, curve: Curves.easeOut);
    widget.onCompletado();
    // Si vuelve a esta pantalla, el círculo está otra vez al inicio.
    if (mounted) _avance.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Empezar',
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final recorrido = restricciones.maxWidth - _perilla - _margen * 2;

          return GestureDetector(
            onTap: _completar,
            onHorizontalDragUpdate: (detalles) {
              _avance.value += detalles.delta.dx / recorrido;
            },
            onHorizontalDragEnd: (_) {
              if (_avance.value > 0.75) {
                _completar();
              } else {
                _avance.animateBack(0, curve: Curves.easeOut);
              }
            },
            child: SizedBox(
              height: _alto,
              child: Vidrio(
                radio: BorderRadius.circular(_alto / 2),
                child: AnimatedBuilder(
                  animation: _avance,
                  builder: (context, _) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Center(
                        child: Opacity(
                          opacity: 1 - _avance.value,
                          child: const Padding(
                            padding: EdgeInsets.only(left: _perilla),
                            child: Text(
                              'Desliza para empezar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: _margen + recorrido * _avance.value,
                        child: Container(
                          width: _perilla,
                          height: _perilla,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF4F4F5),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x59000000),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Color(0xFF0B0C10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
