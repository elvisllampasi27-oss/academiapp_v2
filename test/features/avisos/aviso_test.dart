import 'package:academiapp_v2/features/avisos/domain/aviso.dart';
import 'package:academiapp_v2/features/avisos/presentation/avisos_inicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final ahora = DateTime(2026, 11, 2, 10);

Aviso aviso(
  String id, {
  String? version,
  bool importante = false,
  bool activo = true,
  int diasQueda = 3,
  int creadoHaceDias = 1,
}) => Aviso(
  id: id,
  titulo: 'Aviso $id',
  mensaje: 'Mensaje $id',
  versionId: version,
  importante: importante,
  activo: activo,
  hasta: ahora.add(Duration(days: diasQueda)),
  creadoEn: ahora.subtract(Duration(days: creadoHaceDias)),
);

class Falso implements RepositorioAvisos {
  final List<Aviso> lista;
  Falso(this.lista);

  @override
  Future<List<Aviso>> activos() async => lista;
}

void main() {
  test('cada estudiante ve los vigentes para él, importantes primero', () {
    final lista = avisosPara(
      [
        aviso('viejo', creadoHaceDias: 5),
        aviso('nuevo'),
        aviso('urgente', importante: true, creadoHaceDias: 9),
        aviso('otra-version', version: 'v2'),
        aviso('mi-version', version: 'v1', creadoHaceDias: 3),
        aviso('vencido', diasQueda: -1),
        aviso('pausado', activo: false),
      ],
      versionId: 'v1',
      ahora: ahora,
    );
    expect(
      [for (final a in lista) a.id],
      ['urgente', 'nuevo', 'mi-version', 'viejo'],
    );
  });

  testWidgets('inicio: muestra el aviso y la X lo oculta', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvisosInicio(
            repositorio: Falso([aviso('a')]),
            versionId: 'v1',
            ahora: () => ahora,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aviso a'), findsOneWidget);

    await tester.tap(find.byTooltip('Ocultar'));
    await tester.pump();
    expect(find.text('Aviso a'), findsNothing);
  });
}
