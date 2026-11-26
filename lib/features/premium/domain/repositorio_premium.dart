import 'dart:typed_data';

import 'configuracion_academia.dart';
import 'cupon.dart';
import 'pago.dart';

/// Lo que ve el estudiante en "Premium".
class EstadoPremium {
  final ConfiguracionAcademia configuracion;
  final DateTime? premiumHasta;
  final List<Pago> pagos;

  /// Fin de su prueba gratis (null si nunca la tuvo).
  final DateTime? pruebaHasta;

  const EstadoPremium({
    required this.configuracion,
    required this.premiumHasta,
    required this.pagos,
    this.pruebaHasta,
  });

  /// Su Premium es la prueba gratis (todavía no pagó nada encima).
  bool get enPrueba {
    final hasta = premiumHasta;
    final prueba = pruebaHasta;
    return hasta != null && prueba != null && !hasta.isAfter(prueba);
  }

  Pago? get pendiente =>
      pagos.where((p) => p.estado == EstadoPago.pendiente).firstOrNull;
}

abstract class RepositorioPremium {
  Future<EstadoPremium> cargar(String uid);

  /// null si no existe o no está vigente.
  Future<Cupon?> cupon(String codigo, DateTime ahora);

  /// Lanza [StateError] con un mensaje claro si el N.º ya fue usado.
  Future<void> enviarPago({
    required String uid,
    required String nombre,
    required String correo,
    required MetodoPago metodo,
    required String operacion,
    required int monto,
    String? cupon,
    Uint8List? foto,
  });
}
