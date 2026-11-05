import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/texto_con_latex.dart';

enum EstadoOpcion { normal, elegida, correcta, incorrecta }

/// Alternativa de una pregunta de examen (A, B, C...).
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: fondo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: circulo,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    letra,
                    style: TextStyle(
                      color: letraColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextoConLatex(texto)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
