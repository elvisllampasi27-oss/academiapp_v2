import '../../../premium/domain/repositorio_premium.dart';

/// El alumno confirma escribiendo esta palabra.
const palabraConfirmacion = 'ELIMINAR';

bool confirmacionValida(String texto) =>
    texto.trim().toUpperCase() == palabraConfirmacion;

/// Lo que el alumno pierde si elimina su cuenta, para avisarle antes.
class AvisosEliminacion {
  /// Hasta cuándo tiene Premium, solo si sigue vigente.
  final DateTime? premiumHasta;

  /// Días de Premium que le quedan (redondeado hacia arriba).
  final int diasPremium;

  /// Tiene un pago que todavía no se revisa.
  final bool pagoPendiente;

  const AvisosEliminacion({
    this.premiumHasta,
    this.diasPremium = 0,
    this.pagoPendiente = false,
  });

  factory AvisosEliminacion.desde(EstadoPremium? estado, DateTime ahora) {
    final hasta = estado?.premiumHasta;
    final pendiente = estado?.pendiente != null;
    if (hasta == null || !hasta.isAfter(ahora)) {
      return AvisosEliminacion(pagoPendiente: pendiente);
    }
    final minutos = hasta.difference(ahora).inMinutes;
    return AvisosEliminacion(
      premiumHasta: hasta,
      diasPremium: (minutos / Duration.minutesPerDay).ceil(),
      pagoPendiente: pendiente,
    );
  }
}

/// Mensaje para el alumno según el código de error de la función.
String mensajeErrorEliminacion(String codigo, String? mensajeServidor) {
  return switch (codigo) {
    'not-found' || 'unimplemented' => 'Esta opción estará disponible pronto.',
    'unauthenticated' ||
    'failed-precondition' ||
    'permission-denied' => mensajeServidor ?? 'No se pudo eliminar la cuenta.',
    'unavailable' || 'deadline-exceeded' =>
      'No hay conexión con el servidor. Inténtalo de nuevo.',
    _ => 'No se pudo eliminar la cuenta. Inténtalo de nuevo.',
  };
}
