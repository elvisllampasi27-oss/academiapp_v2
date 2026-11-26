/// Lo que deja listo la preparación de la cuenta: dónde quedó matriculado,
/// cuándo empieza y hasta cuándo dura su prueba gratis.
class PlanPreparado {
  /// false si ya tenía matrícula (no se creó nada).
  final bool nuevo;
  final String? versionNombre;
  final DateTime? inicio;

  /// Fin de la prueba: el lunes a las 00:00 (null si no le tocó prueba).
  final DateTime? pruebaHasta;

  const PlanPreparado({
    required this.nuevo,
    this.versionNombre,
    this.inicio,
    this.pruebaHasta,
  });

  /// Último día de la prueba (el domingo), para mostrarlo.
  DateTime? get ultimoDiaPrueba =>
      pruebaHasta?.subtract(const Duration(days: 1));
}

/// Error con un mensaje listo para mostrar al alumno.
class ExcepcionPreparacionCuenta implements Exception {
  final String mensaje;

  const ExcepcionPreparacionCuenta(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Matricula al alumno en la versión vigente y le da su prueba gratis
/// (función prepararCuenta). Si ya tenía matrícula, no cambia nada.
abstract class ServicioPreparacionCuenta {
  /// Lanza [ExcepcionPreparacionCuenta] con un mensaje claro si no se pudo.
  Future<PlanPreparado> preparar();
}

/// Mensaje para el alumno según el código de error de la función.
String mensajeErrorPreparacion(String codigo, String? mensajeServidor) {
  return switch (codigo) {
    'not-found' || 'unimplemented' =>
      'Tu plan se activará pronto. Mientras tanto, escríbenos y lo '
          'activamos.',
    'failed-precondition' => mensajeServidor ?? 'No pudimos preparar tu plan.',
    'unavailable' || 'deadline-exceeded' =>
      'No hay conexión con el servidor. Inténtalo de nuevo.',
    _ => 'No pudimos preparar tu plan. Inténtalo de nuevo.',
  };
}
