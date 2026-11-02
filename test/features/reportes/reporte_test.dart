import 'package:academiapp_v2/features/reportes/domain/reporte.dart';
import 'package:academiapp_v2/features/reportes/presentation/reportar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Falso implements RepositorioReportes {
  final enviados = <(TipoReporte, String, ContextoReporte)>[];

  @override
  Future<void> enviar({
    required String uid,
    required String nombre,
    required String correo,
    required TipoReporte tipo,
    required String mensaje,
    required ContextoReporte contexto,
  }) async => enviados.add((tipo, mensaje, contexto));

  @override
  Future<List<Reporte>> mios(String uid) async => const [];
}

void main() {
  test('el contexto guarda solo lo que hay', () {
    const c = ContextoReporte(titulo: 'Álgebra · Tema 1', temaId: 't1');
    expect(c.aMapa(), {'titulo': 'Álgebra · Tema 1', 'temaId': 't1'});
    final otra = ContextoReporte.desdeMapa(c.aMapa());
    expect(otra.temaId, 't1');
    expect(otra.examenId, isNull);
    expect(ContextoReporte.desdeMapa(null).titulo, '');
  });

  testWidgets('reportar: pide un mensaje y lo envía con su contexto', (
    tester,
  ) async {
    final falso = Falso();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => mostrarReportar(
                context,
                repositorio: falso,
                autor: const AutorReporte(
                  uid: 'ana',
                  nombre: 'Ana',
                  correo: 'ana@mail.pe',
                ),
                tipo: TipoReporte.preguntaExamen,
                contexto: const ContextoReporte(
                  titulo: 'Exonerados 2025 · pregunta 3',
                  examenId: 'e1',
                  preguntaId: 'e1__p003',
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Muy corto: no se envía.
    await tester.enterText(find.byType(TextField), 'mal');
    await tester.tap(find.text('Enviar reporte'));
    await tester.pump();
    expect(find.text('Cuéntanos un poco más qué pasó.'), findsOneWidget);
    expect(falso.enviados, isEmpty);

    await tester.enterText(find.byType(TextField), 'La clave está mal.');
    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();

    expect(falso.enviados, hasLength(1));
    final (tipo, mensaje, contexto) = falso.enviados.single;
    expect(tipo, TipoReporte.preguntaExamen);
    expect(mensaje, 'La clave está mal.');
    expect(contexto.preguntaId, 'e1__p003');
    expect(find.textContaining('Gracias.'), findsOneWidget);
  });
}
