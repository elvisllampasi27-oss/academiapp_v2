import 'package:flutter/material.dart';

/// Título de un tema que "vuela" de la lista (Inicio, curso) a la barra de
/// la clase al abrirla (animación Hero). Si en la pantalla de origen no
/// está, la clase se abre normal.
class TituloTemaHero extends StatelessWidget {
  final String temaId;
  final String titulo;
  final TextStyle estilo;
  final int maxLines;

  const TituloTemaHero({
    super.key,
    required this.temaId,
    required this.titulo,
    required this.estilo,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'tema-titulo-$temaId',
      // Material transparente: durante el vuelo el texto no pierde su estilo.
      child: Material(
        type: MaterialType.transparency,
        child: Text(
          titulo,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: maxLines > 1,
          style: estilo,
        ),
      ),
    );
  }
}
