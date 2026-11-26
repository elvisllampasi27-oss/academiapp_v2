import 'package:academiapp_v2/features/premium/domain/compra_play.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tienda_falsa.dart';

void main() {
  late TiendaFalsa tienda;
  late List<String> verificados;
  late VerificacionPlay respuesta;
  Object? errorServidor;

  ServicioCompraPlay servicio() => ServicioCompraPlay(
    tienda: tienda,
    verificar: (productoId, token) async {
      verificados.add('$productoId $token');
      if (errorServidor case final e?) throw e;
      return respuesta;
    },
  );

  setUp(() {
    tienda = TiendaFalsa();
    verificados = [];
    respuesta = (activada: true, consumida: true);
    errorServidor = null;
  });

  test('cuenta ofuscada: la misma que calcula el servidor', () {
    expect(
      cuentaOfuscadaPlay('alumnoUid1234567890'),
      '393f34bd9e5f9e8a857aa8d8399524b84cc896ae48594ef43eda032d9ede1559',
    );
  });

  test('compra: verifica en el servidor y avisa la activación', () async {
    final s = servicio();
    var activaciones = 0;
    s.activaciones.listen((_) => activaciones++);

    expect(await s.comprar('ana'), ResultadoCompra.activada);
    expect(tienda.cuentas, [cuentaOfuscadaPlay('ana')]);
    expect(verificados, ['premium_90_dias token-1']);
    // El servidor ya la consumió: no hace falta confirmarla aquí.
    expect(tienda.completadas, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(activaciones, 1);
  });

  test('si el servidor no la consumió, la confirma ante Google', () async {
    respuesta = (activada: true, consumida: false);
    expect(await servicio().comprar('ana'), ResultadoCompra.activada);
    expect(tienda.completadas, ['token-1']);
  });

  test('cancelada: error sin mensaje para mostrar', () async {
    tienda.respuesta = EstadoCompraTienda.cancelada;
    await expectLater(
      servicio().comprar('ana'),
      throwsA(
        isA<ExcepcionCompraPlay>().having((e) => e.cancelada, 'cancelada', true),
      ),
    );
    expect(verificados, isEmpty);
  });

  test('pendiente en Google Play o en el servidor', () async {
    tienda.respuesta = EstadoCompraTienda.pendiente;
    expect(await servicio().comprar('ana'), ResultadoCompra.pendiente);
    expect(verificados, isEmpty);

    tienda = TiendaFalsa();
    respuesta = (activada: false, consumida: false);
    expect(await servicio().comprar('ana'), ResultadoCompra.pendiente);
    expect(tienda.completadas, isEmpty);
  });

  test('errores: el servidor, la tienda y Google Play', () async {
    errorServidor = const ExcepcionCompraPlay('Esta compra es de otra cuenta.');
    await expectLater(
      servicio().comprar('ana'),
      throwsA(
        isA<ExcepcionCompraPlay>().having(
          (e) => e.mensaje,
          'mensaje',
          'Esta compra es de otra cuenta.',
        ),
      ),
    );
    errorServidor = null;

    tienda = TiendaFalsa()..respuesta = EstadoCompraTienda.error;
    await expectLater(
      servicio().comprar('ana'),
      throwsA(isA<ExcepcionCompraPlay>()),
    );

    tienda = TiendaFalsa()..fallaAlAbrir = true;
    await expectLater(
      servicio().comprar('ana'),
      throwsA(
        isA<ExcepcionCompraPlay>().having(
          (e) => e.mensaje,
          'mensaje',
          'No se pudo abrir Google Play.',
        ),
      ),
    );
  });

  test('una compra que quedó a medias se activa sola al volver', () async {
    final s = servicio();
    var activaciones = 0;
    s.activaciones.listen((_) => activaciones++);
    await s.revisarPendientes();
    expect(tienda.restauradas, 1);

    tienda.avisar([
      const CompraTienda(
        productoId: 'otro_producto',
        token: 'x',
        estado: EstadoCompraTienda.restaurada,
      ),
      const CompraTienda(
        productoId: productoPremiumPlay,
        token: 'token-viejo',
        estado: EstadoCompraTienda.restaurada,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(verificados, ['premium_90_dias token-viejo']);
    expect(activaciones, 1);
  });

  test('sin producto en Google Play: null', () async {
    tienda.disponible = null;
    expect(await servicio().cargarProducto(), isNull);
  });

  test('respuesta y mensajes del servidor', () {
    expect(verificacionDesdeMapa({'estado': 'activada', 'consumida': true}), (
      activada: true,
      consumida: true,
    ));
    expect(verificacionDesdeMapa({'estado': 'pendiente'}), (
      activada: false,
      consumida: false,
    ));
    expect(
      mensajeErrorCompra('permission-denied', 'Esta compra es de otra cuenta.'),
      'Esta compra es de otra cuenta.',
    );
    expect(mensajeErrorCompra('unauthenticated', null), 'Inicia sesión otra vez.');
    expect(
      mensajeErrorCompra('internal', 'boom'),
      'No pudimos confirmar tu compra. Inténtalo en un rato.',
    );
  });
}
