import 'package:flutter/material.dart';

/// Pantalla "en carga" con la forma de lo que viene (bloques grises con un
/// brillo que pasa), en lugar de un círculo girando. Con "reducir
/// animaciones" los bloques quedan quietos.
class Esqueleto extends StatefulWidget {
  final Widget child;

  const Esqueleto({super.key, required this.child});

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _brillo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quieto = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (quieto) {
      _brillo.stop();
    } else if (!_brillo.isAnimating) {
      _brillo.repeat();
    }
  }

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: AnimatedBuilder(
        animation: _brillo,
        child: widget.child,
        builder: (context, child) {
          final x = -1.5 + 3 * _brillo.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(x - 0.6, 0),
              end: Alignment(x + 0.6, 0),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x14FFFFFF),
                Color(0x00FFFFFF),
              ],
            ).createShader(rect),
            child: child,
          );
        },
      ),
    );
  }
}

/// Un bloque gris del esqueleto.
class Hueso extends StatelessWidget {
  final double alto;
  final double? ancho;
  final double radio;

  const Hueso({super.key, this.alto = 14, this.ancho, this.radio = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: alto,
      width: ancho,
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(radio),
      ),
    );
  }
}

/// Lista de tarjetas en carga (título + dos líneas).
class EsqueletoLista extends StatelessWidget {
  final int tarjetas;
  final EdgeInsetsGeometry padding;

  const EsqueletoLista({
    super.key,
    this.tarjetas = 3,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Esqueleto(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tarjetas; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x14FFFFFF)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.55,
                      child: Hueso(alto: 16),
                    ),
                    SizedBox(height: 12),
                    Hueso(),
                    SizedBox(height: 8),
                    FractionallySizedBox(widthFactor: 0.7, child: Hueso()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// El Inicio en carga: saludo, la tarjeta de "Hoy" y dos más.
class EsqueletoInicio extends StatelessWidget {
  const EsqueletoInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Esqueleto(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hueso(alto: 12, ancho: 140),
              SizedBox(height: 10),
              Hueso(alto: 30, ancho: 200),
              SizedBox(height: 24),
              Hueso(alto: 220, radio: 24),
              SizedBox(height: 24),
              Hueso(alto: 18, ancho: 150),
              SizedBox(height: 12),
              Hueso(alto: 84, radio: 18),
              SizedBox(height: 12),
              Hueso(alto: 84, radio: 18),
            ],
          ),
        ),
      ),
    );
  }
}
