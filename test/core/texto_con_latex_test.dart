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

    // P(x) = a_nx^n se parte después del "=": 2 pedazos + x^2.
    expect(find.byType(Math), findsNWidgets(3));
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('las negritas se muestran sin asteriscos', (tester) async {
    await mostrar(tester, 'Un **polinomio** tiene exponentes enteros.');

    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('polinomio'), findsOneWidget);
  });

  testWidgets('una fórmula larga baja de línea en vez de desbordarse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await mostrar(
      tester,
      r'$P(t) = 4000 \Rightarrow 10^3(2\cos Bt + 3) = 4000 \Rightarrow '
      r'2\cos Bt + 3 = 4 \Rightarrow \cos Bt = \frac{1}{2}$. Listo.',
    );

    // Sin el arreglo, Flutter lanza "RIGHT OVERFLOWED BY ... PIXELS".
    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsAtLeastNWidgets(4));
  });
}
