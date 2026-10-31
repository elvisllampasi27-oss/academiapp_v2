import 'package:academiapp_v2/core/presentation/texto_con_latex.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mostrar(WidgetTester tester, String texto) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TextoConLatex(texto))),
    );
  }

  testWidgets('formulas en linea y en bloque sin dejar signos de dolar', (
    tester,
  ) async {
    await mostrar(tester, r'Forma general: $$P(x) = a_nx^n$$ y $x^2$.');

    expect(find.byType(Math), findsNWidgets(2));
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('las negritas se muestran sin asteriscos', (tester) async {
    await mostrar(tester, 'Un **polinomio** tiene exponentes enteros.');

    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('polinomio'), findsOneWidget);
  });
}
