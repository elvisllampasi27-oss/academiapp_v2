import 'cupon.dart';

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

/// Por qué no se puede aprobar [pago] con su cupón, o null si se puede.
/// [cupon] es el cupón tal como está ahora (null si ya no existe). La
/// vigencia se mide en la fecha en que el estudiante envió el pago.
String? problemaDeCupon(Pago pago, Cupon? cupon) {
  final codigo = pago.cupon;
  if (codigo == null) {
    return pago.metodo == MetodoPago.beca ? 'Esta beca no tiene cupón.' : null;
  }
  if (cupon == null) return 'El cupón $codigo no existe.';
  if (pago.metodo == MetodoPago.beca && cupon.tipo != TipoCupon.premiumGratis) {
    return 'El cupón $codigo no es de Premium gratis: no sirve como beca.';
  }
  if (!cupon.activo) return 'El cupón $codigo está desactivado.';
  if (cupon.vence case final vence? when vence.isBefore(pago.creadoEn)) {
    return 'El cupón $codigo ya había vencido cuando se envió el pago.';
  }
  if (cupon.usosMaximos case final maximo? when cupon.usos >= maximo) {
    return 'El cupón $codigo ya se usó las $maximo veces permitidas.';
  }
  return null;
}
