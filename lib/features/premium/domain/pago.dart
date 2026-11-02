enum EstadoPago { pendiente, aprobado, rechazado }

enum MetodoPago {
  yape('Yape'),
  plin('Plin'),
  beca('Beca'),
  manual('Dado por el administrador');

  final String etiqueta;
  const MetodoPago(this.etiqueta);
}

/// Pago de Premium (documento `pagos/{metodo}__{operacion}`). El id evita
/// que dos estudiantes reclamen la misma operación de Yape. Una beca
/// (cupón de Premium gratis) también pasa por aquí con monto 0.
class Pago {
  final String id;
  final String usuarioId;
  final String nombre;
  final String correo;
  final int monto;
  final MetodoPago metodo;
  final String operacion;
  final String? cupon;
  final EstadoPago estado;
  final DateTime creadoEn;
  final DateTime? revisadoEn;
  final String? revisadoPor;
  final String? motivo;
  final DateTime? premiumHasta;
  final DateTime? premiumAnterior;
  final String? fotoUrl;

  const Pago({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.correo,
    required this.monto,
    required this.metodo,
    required this.operacion,
    required this.estado,
    required this.creadoEn,
    this.cupon,
    this.revisadoEn,
    this.revisadoPor,
    this.motivo,
    this.premiumHasta,
    this.premiumAnterior,
    this.fotoUrl,
  });
}

/// Solo dígitos: "N.º 00-45812" -> "0045812".
String normalizarOperacion(String operacion) =>
    operacion.replaceAll(RegExp(r'[^0-9]'), '');

/// Un N.º de operación de Yape/Plin tiene entre 6 y 20 dígitos.
bool operacionValida(String operacion) {
  final n = normalizarOperacion(operacion);
  return n.length >= 6 && n.length <= 20;
}

/// Id del pago: por N.º de operación (Yape/Plin) o, para una beca, uno por
/// estudiante y cupón.
String idPago({
  required MetodoPago metodo,
  required String operacion,
  required String uid,
  String? cupon,
}) => metodo == MetodoPago.beca
    ? 'beca__${uid}__$cupon'
    : '${metodo.name}__${normalizarOperacion(operacion)}';
