import 'dart:async';

import 'package:academiapp_v2/features/premium/domain/compra_play.dart';

/// Google Play de mentira: al comprar, responde con [respuesta].
class TiendaFalsa implements TiendaPlay {
  final _compras = StreamController<List<CompraTienda>>.broadcast();
  ProductoPlay? disponible = const ProductoPlay(
    id: productoPremiumPlay,
    precio: 'S/ 35.00',
  );

  /// Lo que avisa Google Play al cerrar la hoja de pago. null: nada.
  EstadoCompraTienda? respuesta = EstadoCompraTienda.comprada;
  bool porCompletar = true;
  bool fallaAlAbrir = false;
  final cuentas = <String>[];
  final completadas = <String>[];
  var restauradas = 0;

  void avisar(List<CompraTienda> compras) => _compras.add(compras);

  @override
  Stream<List<CompraTienda>> get compras => _compras.stream;

  @override
  Future<ProductoPlay?> producto(String id) async =>
      disponible?.id == id ? disponible : null;

  @override
  Future<void> comprar(String productoId, {required String cuenta}) async {
    if (fallaAlAbrir) throw StateError('sin Google Play');
    cuentas.add(cuenta);
    final r = respuesta;
    if (r != null) {
      avisar([
        CompraTienda(
          productoId: productoId,
          token: 'token-1',
          estado: r,
          porCompletar: porCompletar,
        ),
      ]);
    }
  }

  @override
  Future<void> restaurar() async => restauradas++;

  @override
  Future<void> completar(CompraTienda compra) async =>
      completadas.add(compra.token);
}
