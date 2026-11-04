import 'package:flutter/material.dart';

/// Texto que "vuela" de una lista a la barra de la pantalla que abre
/// (animación Hero / shared element). [etiqueta] debe ser la misma en las
/// dos pantallas y única en cada una.
class TituloQueVuela extends StatelessWidget {
  final String etiqueta;
  final String texto;
  final TextStyle estilo;
  final int maxLines;

  const TituloQueVuela({
    super.key,
    required this.etiqueta,
    required this.texto,
    required this.estilo,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: etiqueta,
      // Material transparente: durante el vuelo el texto no pierde su estilo.
      child: Material(
        type: MaterialType.transparency,
        child: Text(
          texto,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: maxLines > 1,
          style: estilo,
        ),
      ),
    );
  }
}
