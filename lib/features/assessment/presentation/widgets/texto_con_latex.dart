import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Texto con fórmulas LaTeX en línea: `$x^2 + 1$`.
/// Reutilizado de AcademiApp V1 (lib/widgets/texto_latex.dart); ahora toma
/// el estilo del tema en lugar de forzar texto blanco.
class TextoConLatex extends StatelessWidget {
  final String texto;
  final TextStyle? estilo;

  const TextoConLatex(this.texto, {super.key, this.estilo});

  static final _formula = RegExp(r'\$([^$\n]+?)\$');

  @override
  Widget build(BuildContext context) {
    final estiloBase = DefaultTextStyle.of(context).style
        .merge(estilo)
        .copyWith(height: 1.5);

    if (!texto.contains(r'$')) {
      return Text(texto, style: estiloBase);
    }

    final partes = <InlineSpan>[];
    var ultimo = 0;

    for (final coincidencia in _formula.allMatches(texto)) {
      if (coincidencia.start > ultimo) {
        partes.add(TextSpan(text: texto.substring(ultimo, coincidencia.start)));
      }

      final formula = coincidencia.group(1)!;

      partes.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            formula,
            textStyle: estiloBase,
            onErrorFallback: (_) => Text(
              formula,
              style: estiloBase.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );

      ultimo = coincidencia.end;
    }

    if (ultimo < texto.length) {
      partes.add(TextSpan(text: texto.substring(ultimo)));
    }

    return Text.rich(TextSpan(style: estiloBase, children: partes));
  }
}
