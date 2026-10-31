import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Texto con fórmulas LaTeX en línea: `$x^2 + 1$`.
/// Reutilizado de AcademiApp V1 (lib/widgets/texto_latex.dart); ahora toma
/// el estilo del tema en lugar de forzar texto blanco.
class TextoConLatex extends StatelessWidget {
  final String texto;
  final TextStyle? estilo;

  const TextoConLatex(this.texto, {super.key, this.estilo});

  /// `$$...$$` (en bloque) o `$...$` (en línea).
  static final _formula = RegExp(r'\$\$([^$]+?)\$\$|\$([^$\n]+?)\$');
  static final _negrita = RegExp(r'\*\*(.+?)\*\*');

  /// Texto normal con `**negritas**` (las usa el tutor).
  static List<InlineSpan> _texto(String texto) {
    final partes = <InlineSpan>[];
    var ultimo = 0;

    for (final m in _negrita.allMatches(texto)) {
      if (m.start > ultimo) {
        partes.add(TextSpan(text: texto.substring(ultimo, m.start)));
      }
      partes.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      ultimo = m.end;
    }

    if (ultimo < texto.length) {
      partes.add(TextSpan(text: texto.substring(ultimo)));
    }

    return partes;
  }

  @override
  Widget build(BuildContext context) {
    final estiloBase = DefaultTextStyle.of(context).style
        .merge(estilo)
        .copyWith(height: 1.5);

    if (!texto.contains(r'$') && !texto.contains('**')) {
      return Text(texto, style: estiloBase);
    }

    final partes = <InlineSpan>[];
    var ultimo = 0;

    for (final coincidencia in _formula.allMatches(texto)) {
      if (coincidencia.start > ultimo) {
        partes.addAll(_texto(texto.substring(ultimo, coincidencia.start)));
      }

      final formula = (coincidencia.group(1) ?? coincidencia.group(2)!).trim();

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
      partes.addAll(_texto(texto.substring(ultimo)));
    }

    return Text.rich(TextSpan(style: estiloBase, children: partes));
  }
}
