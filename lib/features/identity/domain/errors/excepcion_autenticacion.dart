/// Errores de autenticación expresados en el lenguaje de AcademiApp,
/// independientes del proveedor (FirebaseAuth u otro).
enum TipoErrorAutenticacion {
  credencialesInvalidas,
  correoInvalido,
  correoEnUso,
  contrasenaDebil,
  demasiadosIntentos,
  cuentaDeshabilitada,
  sinConexion,
  operacionNoPermitida,
  cancelado,
  ventanaBloqueada,
  desconocido,
}

class ExcepcionAutenticacion implements Exception {
  final TipoErrorAutenticacion tipo;
  final String? detalle;

  const ExcepcionAutenticacion(this.tipo, {this.detalle});

  @override
  String toString() =>
      'ExcepcionAutenticacion($tipo${detalle == null ? '' : ': $detalle'})';
}
