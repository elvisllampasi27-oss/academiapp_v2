import 'package:academiapp_v2/features/identity/presentation/pages/bienvenida_page.dart';
import 'package:academiapp_v2/features/identity/presentation/widgets/estilo_autenticacion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mostrar(WidgetTester tester, {required bool desdeCarga}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BienvenidaPage(
          desdeCarga: desdeCarga,
          onEmpezar: () {},
          onCrearCuenta: () {},
        ),
      ),
    );
  }

  Opacity botonEmpezar(WidgetTester tester) => tester.widget(
    find
        .ancestor(
          of: find.byType(DeslizadorEmpezar),
          matching: find.byType(Opacity),
        )
        .first,
  );

  Image puma(WidgetTester tester) => tester.widget(
    find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == PumaDeFondo.ruta,
    ),
  );

  testWidgets('desde la carga: el puma queda de fondo y el botón baja', (
    tester,
  ) async {
    await mostrar(tester, desdeCarga: true);

    // Al principio: el puma entero (como lo dejó la carga), sin botón.
    expect(puma(tester).opacity!.value, 1);
    expect(botonEmpezar(tester).opacity, 0);

    await tester.pumpAndSettle();
    expect(puma(tester).opacity!.value, closeTo(PumaDeFondo.opacidad, 1e-6));
    expect(botonEmpezar(tester).opacity, 1);
  });

  testWidgets('sin venir de la carga todo está en su lugar desde el inicio', (
    tester,
  ) async {
    await mostrar(tester, desdeCarga: false);
    expect(puma(tester).opacity!.value, closeTo(PumaDeFondo.opacidad, 1e-6));
    expect(botonEmpezar(tester).opacity, 1);
  });

  testWidgets('las letras de acceso usan Comic Neue', (tester) async {
    await mostrar(tester, desdeCarga: false);
    final estilo = DefaultTextStyle.of(
      tester.element(find.text('Tu ingreso a la UNSCH empieza aquí')),
    ).style;
    expect(estilo.fontFamily, fuenteAcceso);
  });
}
