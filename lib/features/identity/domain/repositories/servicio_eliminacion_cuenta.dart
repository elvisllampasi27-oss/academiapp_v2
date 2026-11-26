/// Cómo entró el alumno: define cómo se le pide volver a identificarse.
enum MetodoIngreso { contrasena, google }

/// Error con un mensaje listo para mostrar al alumno.
class ExcepcionEliminacionCuenta implements Exception {
  final String mensaje;

  const ExcepcionEliminacionCuenta(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Borra la cuenta del alumno y todos sus datos (función eliminarMiCuenta).
abstract class ServicioEliminacionCuenta {
  MetodoIngreso metodoIngreso();

  /// Firebase exige un ingreso reciente para borrar la cuenta.
  Future<void> reautenticarConContrasena(String contrasena);

  Future<void> reautenticarConGoogle();

  /// Lanza [ExcepcionEliminacionCuenta] con un mensaje claro si no se pudo.
  Future<void> eliminarMiCuenta();
}
