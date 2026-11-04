import 'package:flutter/material.dart';

import '../../../../core/presentation/titulo_que_vuela.dart';

/// Título de un tema que vuela de la lista (Inicio, curso) a la barra de la
/// clase. Si en la pantalla de origen no está, la clase se abre normal.
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
  Widget build(BuildContext context) => TituloQueVuela(
    etiqueta: 'tema-titulo-$temaId',
    texto: titulo,
    estilo: estilo,
    maxLines: maxLines,
  );
}
