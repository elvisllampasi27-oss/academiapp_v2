import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/compra_play.dart';

/// Google Play Billing con el plugin in_app_purchase.
class TiendaGooglePlay implements TiendaPlay {
  final InAppPurchase _tienda;
  final _detalles = <String, ProductDetails>{};

  TiendaGooglePlay({InAppPurchase? tienda})
    : _tienda = tienda ?? InAppPurchase.instance;

  @override
  Stream<List<CompraTienda>> get compras => _tienda.purchaseStream.map(
    (lista) => [for (final p in lista) _aCompra(p)],
  );

  CompraTienda _aCompra(PurchaseDetails p) => CompraTienda(
    productoId: p.productID,
    // En Android es el purchaseToken.
    token: p.verificationData.serverVerificationData,
    estado: switch (p.status) {
      PurchaseStatus.pending => EstadoCompraTienda.pendiente,
      PurchaseStatus.purchased => EstadoCompraTienda.comprada,
      PurchaseStatus.restored => EstadoCompraTienda.restaurada,
      PurchaseStatus.canceled => EstadoCompraTienda.cancelada,
      PurchaseStatus.error => EstadoCompraTienda.error,
    },
    porCompletar: p.pendingCompletePurchase,
    original: p,
  );

  @override
  Future<ProductoPlay?> producto(String id) async {
    if (!await _tienda.isAvailable()) return null;
    final respuesta = await _tienda.queryProductDetails({id});
    final detalle = respuesta.productDetails
        .where((d) => d.id == id)
        .firstOrNull;
    if (detalle == null) return null;
    _detalles[id] = detalle;
    return ProductoPlay(id: id, precio: detalle.price);
  }

  @override
  Future<void> comprar(String productoId, {required String cuenta}) async {
    if (!_detalles.containsKey(productoId)) await producto(productoId);
    final detalle = _detalles[productoId];
    if (detalle == null) throw StateError('Producto no disponible.');
    // Se consume en el servidor después de dar Premium (así no se pierde
    // la compra si falla la verificación).
    final abierta = await _tienda.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: detalle,
        applicationUserName: cuenta,
      ),
      autoConsume: false,
    );
    if (!abierta) throw StateError('No se pudo abrir la compra.');
  }

  @override
  Future<void> restaurar() => _tienda.restorePurchases();

  @override
  Future<void> completar(CompraTienda compra) async {
    if (compra.original case final PurchaseDetails p) {
      await _tienda.completePurchase(p);
    }
  }
}

/// Verificación con la función verificarCompraPlay.
VerificarCompraPlay verificarCompraConFirebase({FirebaseFunctions? functions}) {
  final f = functions ?? FirebaseFunctions.instance;
  return (productoId, token) async {
    try {
      final r = await f
          .httpsCallable('verificarCompraPlay')
          .call<Map<Object?, Object?>>({
            'productoId': productoId,
            'token': token,
          });
      return verificacionDesdeMapa(r.data);
    } on FirebaseFunctionsException catch (e) {
      throw ExcepcionCompraPlay(mensajeErrorCompra(e.code, e.message));
    }
  };
}
