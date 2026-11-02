import '../../features/premium/domain/configuracion_academia.dart';
import '../../features/premium/domain/cupon.dart';
import '../../features/premium/domain/pago.dart';

/// Pagos de Premium: revisar, aprobar, rechazar y revertir. Nada se borra;
/// cada cambio deja su entrada en el registro de acciones.
abstract class RepositorioPagosAdmin {
  /// Cantidad de pagos por revisar, en vivo (para el menú lateral).
  Stream<int> pendientes();

  Future<List<Pago>> pagos(EstadoPago estado);

  Future<List<Pago>> pagosDe(String uid);

  /// Activa o extiende Premium [dias] días. Devuelve el nuevo vencimiento.
  Future<DateTime> aprobar(Pago pago, {required int dias});

  Future<void> rechazar(Pago pago, {required String motivo});

  /// Vuelve el pago a "por revisar" (y deshace el Premium si se aprobó).
  Future<void> revertir(Pago pago);

  /// Premium sin pago (cortesía, compensación…). Queda como pago "manual".
  Future<DateTime> darPremium({
    required String uid,
    required String nombre,
    required String correo,
    required int dias,
    required String motivo,
  });
}

/// Configuración de la academia y cupones.
abstract class RepositorioAcademiaAdmin {
  Future<ConfiguracionAcademia> configuracion();

  Future<void> guardarConfiguracion(ConfiguracionAcademia c);

  Future<List<Cupon>> cupones();

  /// Lanza [StateError] si se crea un código que ya existe.
  Future<void> guardarCupon(Cupon cupon, {required bool nuevo});
}
