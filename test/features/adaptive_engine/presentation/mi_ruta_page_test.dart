import 'package:academiapp_v2/features/adaptive_engine/domain/services/construir_mi_ruta_service.dart';
import 'package:academiapp_v2/features/adaptive_engine/presentation/pages/mi_ruta_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes_mi_ruta.dart';

void main() {
  testWidgets('agrupa por tipo, muestra el dominio y abre el tema', (
    tester,
  ) async {
    final abiertos = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MiRutaPage(
          service: ConstruirMiRutaService(
            repositorio: RepositorioEvidenciaEnMemoria(
              evidenciasDe('aritmetica-02__general', [false, false]),
              const {'aritmetica-02__general': 'aritmetica-02'},
            ),
          ),
          usuarioId: 'u',
          matriculaId: 'm1',
          describirTema: (temaId) => temaId == 'aritmetica-02'
              ? (titulo: 'Magnitudes proporcionales', curso: 'Aritmética')
              : null,
          onAbrirTema: abiertos.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reforzar'), findsOneWidget);
    expect(find.text('Practicar'), findsNothing);
    expect(find.text('Magnitudes proporcionales'), findsOneWidget);
    expect(find.textContaining('2 respuestas'), findsOneWidget);

    await tester.tap(find.text('Magnitudes proporcionales'));
    expect(abiertos, ['aritmetica-02']);
  });

  testWidgets('sin datos explica que hacer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MiRutaPage(
          service: ConstruirMiRutaService(
            repositorio: RepositorioEvidenciaEnMemoria(const []),
          ),
          usuarioId: 'u',
          matriculaId: 'm1',
          describirTema: (_) => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Todavía no hay datos'), findsOneWidget);
  });
}
