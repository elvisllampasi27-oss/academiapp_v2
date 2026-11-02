import 'package:academiapp_v2/admin/pagos/pagos_page.dart';
import 'package:academiapp_v2/admin/pagos/repositorio_pagos_admin.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/premium/domain/configuracion_academia.dart';
import 'package:academiapp_v2/features/premium/domain/cupon.dart';
import 'package:academiapp_v2/features/premium/domain/pago.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final hoy = DateTime(2026, 11, 1, 10);

final pagoAna = Pago(
  id: 'yape__0045812',
  usuarioId: 'ana',
  nombre: 'Ana Quispe',
  correo: 'ana@mail.pe',
  monto: 29,
  metodo: MetodoPago.yape,
  operacion: '0045812',
  estado: EstadoPago.pendiente,
  creadoEn: DateTime(2026, 11, 1, 9),
);

class Falso implements RepositorioPagosAdmin, RepositorioAcademiaAdmin {
  final hechos = <String>[];

  @override
  Stream<int> pendientes() => Stream.value(1);

  @override
  Future<List<Pago>> pagos(EstadoPago estado) async =>
      estado == EstadoPago.pendiente && hechos.isEmpty ? [pagoAna] : [];

  @override
  Future<List<Pago>> pagosDe(String uid) async => [pagoAna];

  @override
  Future<DateTime> aprobar(Pago pago, {required int dias}) async {
    hechos.add('aprobar ${pago.id} $dias');
    return hoy.add(Duration(days: dias));
  }

  @override
  Future<void> rechazar(Pago pago, {required String motivo}) async =>
      hechos.add('rechazar ${pago.id} $motivo');

  @override
  Future<void> revertir(Pago pago) async => hechos.add('revertir');

  @override
  Future<DateTime> darPremium({
    required String uid,
    required String nombre,
    required String correo,
    required int dias,
    required String motivo,
  }) async => hoy;

  @override
  Future<ConfiguracionAcademia> configuracion() async =>
      const ConfiguracionAcademia();

  @override
  Future<void> guardarConfiguracion(ConfiguracionAcademia c) async {}

  @override
  Future<List<Cupon>> cupones() async => const [];

  @override
  Future<void> guardarCupon(Cupon cupon, {required bool nuevo}) async {}
}

void main() {
  testWidgets('pagos: solo se aprueba después de verificar', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final falso = Falso();
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: PagosPage(
            pagos: falso,
            academia: falso,
            onAbrirEstudiante: (_) {},
            ahora: () => hoy,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Por revisar · 1'), findsOneWidget);
    expect(find.text('Ana Quispe'), findsWidgets);

    // FilledButton.icon crea una subclase: se busca por "es un FilledButton".
    final aprobar = find.ancestor(
      of: find.text('Aprobar · Premium hasta 30 ene*'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(tester.widget<FilledButton>(aprobar).onPressed, isNull);

    await tester.tap(find.text('Llegó S/ 29 al Yape de la academia'));
    await tester.tap(find.text('El N.º de operación 0045812 coincide'));
    await tester.pump();
    expect(tester.widget<FilledButton>(aprobar).onPressed, isNotNull);

    await tester.tap(aprobar);
    await tester.pumpAndSettle();
    expect(falso.hechos, ['aprobar yape__0045812 90']);
    expect(find.text('No hay pagos por revisar.'), findsOneWidget);
  });
}
