import 'package:academiapp_v2/admin/sistema/estado_sistema_page.dart';
import 'package:academiapp_v2/admin/sistema/sonda_sistema.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Falsa implements SondaSistema {
  int revisiones = 0;

  @override
  EntornoPanel get entorno => const EntornoPanel(
    proyecto: 'demo-academiapp',
    emuladorFunctions: true,
    emuladorStorage: false,
  );

  @override
  Future<List<ChequeoServicio>> revisar() async {
    revisiones++;
    return const [
      ChequeoServicio(
        servicio: 'Base de datos (Firestore)',
        nivel: NivelEstado.bien,
        detalle: 'Responde bien.',
        milisegundos: 120,
      ),
      ChequeoServicio(
        servicio: 'Archivos (Storage)',
        nivel: NivelEstado.caido,
        detalle: 'No responde.',
      ),
    ];
  }
}

void main() {
  testWidgets('estado: muestra cada servicio y lo pendiente', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final sonda = Falsa();
    var pagos = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: EstadoSistemaPage(
            sonda: sonda,
            pagosPendientes: Stream.value(2),
            reportesNuevos: Stream.value(0),
            onVerPagos: () => pagos++,
            onVerReportes: () {},
            ahora: () => DateTime(2026, 11, 2, 10, 5),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hay servicios que no responden'), findsOneWidget);
    expect(find.text('Responde'), findsOneWidget);
    expect(find.text('No responde'), findsOneWidget);
    expect(find.text('120 ms'), findsOneWidget);
    expect(find.text('demo-academiapp'), findsOneWidget);
    expect(find.text('Emulador local'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Ver').first);
    expect(pagos, 1);

    await tester.tap(find.text('Revisar de nuevo'));
    await tester.pumpAndSettle();
    expect(sonda.revisiones, 2);
  });
}
