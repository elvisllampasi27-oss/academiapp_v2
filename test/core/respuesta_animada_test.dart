import 'package:academiapp_v2/core/presentation/respuesta_animada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Sin MaterialApp: así el único Transform posible es el de la animación.
Widget caja(ReaccionRespuesta? reaccion, {bool sinAnimaciones = false}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: sinAnimaciones),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RespuestaAnimada(
            reaccion: reaccion,
            child: const SizedBox(key: Key('caja'), width: 40, height: 40),
          ),
        ),
      ),
    );

Matrix4? transformacion(WidgetTester tester) {
  final t = find.ancestor(
    of: find.byKey(const Key('caja')),
    matching: find.byType(Transform),
  );
  return t.evaluate().isEmpty
      ? null
      : tester.widget<Transform>(t.first).transform;
}

void main() {
  testWidgets('al acertar da un salto y vuelve a su tamaño', (tester) async {
    await tester.pumpWidget(caja(null));
    expect(transformacion(tester), isNull);

    await tester.pumpWidget(caja(ReaccionRespuesta.acierto));
    await tester.pump(const Duration(milliseconds: 220));
    expect(transformacion(tester)!.getMaxScaleOnAxis(), greaterThan(1.03));

    await tester.pumpAndSettle();
    expect(transformacion(tester), isNull);
  });

  testWidgets('al fallar tiembla de lado', (tester) async {
    await tester.pumpWidget(caja(null));
    await tester.pumpWidget(caja(ReaccionRespuesta.error));
    await tester.pump(const Duration(milliseconds: 60));
    expect(transformacion(tester)!.getTranslation().x, isNot(0));
    await tester.pumpAndSettle();
  });

  testWidgets('con "reducir animaciones" no se mueve', (tester) async {
    await tester.pumpWidget(caja(null, sinAnimaciones: true));
    await tester.pumpWidget(
      caja(ReaccionRespuesta.acierto, sinAnimaciones: true),
    );
    await tester.pump(const Duration(milliseconds: 220));
    expect(transformacion(tester), isNull);
  });
}
