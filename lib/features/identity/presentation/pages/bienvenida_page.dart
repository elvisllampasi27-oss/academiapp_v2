import 'package:flutter/material.dart';

import '../widgets/estilo_autenticacion.dart';

/// Primera pantalla para quien no ha iniciado sesión.
class BienvenidaPage extends StatelessWidget {
  final VoidCallback onEmpezar;
  final VoidCallback onCrearCuenta;

  const BienvenidaPage({
    super.key,
    required this.onEmpezar,
    required this.onCrearCuenta,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/fondo_autenticacion.jpeg',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x59050609),
                  Color(0x1A050609),
                  Color(0xE0050609),
                ],
                stops: [0, 0.35, 0.78],
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
                            Align(
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 120),
                                const Text(
                                  'Tu ingreso a la UNSCH empieza aquí',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 44,
                                    height: 1.0,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Temas cada día, práctica con corrección al '
                                  'instante y una ruta que se adapta a lo que '
                                  'te falta.',
                                  style: TextStyle(
                                    color: Color(0xFFD4D4D8),
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                DeslizadorEmpezar(onCompletado: onEmpezar),
                                const SizedBox(height: 12),
                                PreguntaConEnlace(
                                  pregunta: '¿Primera vez?',
                                  enlace: 'Crear cuenta',
                                  alPresionar: onCrearCuenta,
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
