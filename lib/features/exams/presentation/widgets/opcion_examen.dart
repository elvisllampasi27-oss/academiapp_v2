import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/texto_con_latex.dart';
import '../../../../core/presentation/animaciones.dart';

enum EstadoOpcion { normal, elegida, correcta, incorrecta }

/// Alternativa de una pregunta de examen (A, B, C...). Los colores cambian
/// suave; al elegirla o al salir correcta se hunde y vuelve, y si sale
/// incorrecta se sacude una vez.
class OpcionExamenTile extends StatelessWidget {
  final String letra;
  final String texto;
  final EstadoOpcion estado;
  final VoidCallback? alPresionar;

  const OpcionExamenTile({
    super.key,
    required this.letra,
    required this.texto,
    this.estado = EstadoOpcion.normal,
    this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    final (fondo, borde, circulo, letraColor) = switch (estado) {
      EstadoOpcion.normal => (
        ColoresApp.panel,
        ColoresApp.borde,
        const Color(0x1AFFFFFF),
        ColoresApp.texto,
      ),
      EstadoOpcion.elegida => (
        const Color(0x1FFFFFFF),
        ColoresApp.bordeFuerte,
        ColoresApp.texto,
        ColoresApp.fondo,
      ),
      EstadoOpcion.correcta => (
        ColoresApp.celeste.withValues(alpha: 0.14),
        ColoresApp.celeste,
        ColoresApp.celeste,
        ColoresApp.fondo,
      ),
      EstadoOpcion.incorrecta => (
        ColoresApp.naranja.withValues(alpha: 0.14),
        ColoresApp.naranja,
        ColoresApp.naranja,
        ColoresApp.fondo,
      ),
    };

    final duracion = sinAnimaciones(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Reaccion(
        golpe: switch (estado) {
          EstadoOpcion.normal => Golpe.ninguno,
          EstadoOpcion.elegida || EstadoOpcion.correcta => Golpe.pulso,
          EstadoOpcion.incorrecta => Golpe.sacudida,
        },
        disparo: estado,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: fondo),
          duration: duracion,
          builder: (context, colorFondo, hijo) => Material(
            color: colorFondo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borde),
            ),
            clipBehavior: Clip.antiAlias,
            child: hijo,
          ),
          child: InkWell(
            onTap: alPresionar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: duracion,
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: circulo,
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: duracion,
                      style: TextStyle(
                        color: letraColor,
                        fontWeight: FontWeight.w700,
                      ),
                      child: Text(letra),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: TextoConLatex(texto)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
