import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/cupon.dart';
import '../domain/pago.dart';

DateTime? _fecha(Object? v) => v is Timestamp ? v.toDate() : null;

Pago? pagoDesdeMapa(String id, Map<String, dynamic> m) {
  final metodo = MetodoPago.values.asNameMap()[m['metodo']];
  final estado = EstadoPago.values.asNameMap()[m['estado']];
  final usuarioId = m['usuarioId'];
  if (metodo == null || estado == null || usuarioId is! String) return null;
  return Pago(
    id: id,
    usuarioId: usuarioId,
    nombre: (m['nombre'] as String?) ?? '',
    correo: (m['correo'] as String?) ?? '',
    monto: (m['monto'] as num?)?.toInt() ?? 0,
    metodo: metodo,
    operacion: (m['operacion'] as String?) ?? '',
    cupon: m['cupon'] as String?,
    estado: estado,
    // Recién creado, la hora del servidor puede venir vacía un instante.
    creadoEn: _fecha(m['creadoEn']) ?? DateTime.now(),
    revisadoEn: _fecha(m['revisadoEn']),
    revisadoPor: m['revisadoPor'] as String?,
    motivo: m['motivo'] as String?,
    premiumHasta: _fecha(m['premiumHasta']),
    premiumAnterior: _fecha(m['premiumAnterior']),
    fotoUrl: m['fotoUrl'] as String?,
  );
}

Cupon? cuponDesdeMapa(String codigo, Map<String, dynamic> m) {
  final tipo = TipoCupon.values.asNameMap()[m['tipo']];
  if (tipo == null) return null;
  return Cupon(
    codigo: codigo,
    tipo: tipo,
    valor: (m['valor'] as num?)?.toInt() ?? 0,
    usosMaximos: (m['usosMaximos'] as num?)?.toInt(),
    usos: (m['usos'] as num?)?.toInt() ?? 0,
    vence: _fecha(m['vence']),
    activo: m['activo'] != false,
  );
}

Map<String, Object?> cuponAMapa(Cupon c) => {
  'tipo': c.tipo.name,
  'valor': c.valor,
  'usosMaximos': c.usosMaximos,
  'usos': c.usos,
  'vence': c.vence == null ? null : Timestamp.fromDate(c.vence!),
  'activo': c.activo,
};
