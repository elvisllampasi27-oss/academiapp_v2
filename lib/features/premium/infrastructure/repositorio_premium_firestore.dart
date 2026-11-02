import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/configuracion_academia.dart';
import '../domain/cupon.dart';
import '../domain/pago.dart';
import '../domain/repositorio_premium.dart';
import '../domain/servicio_comprobante.dart';
import 'premium_desde_mapa.dart';

class RepositorioPremiumFirestore implements RepositorioPremium {
  final FirebaseFirestore db;
  final ServicioComprobante? comprobantes;

  RepositorioPremiumFirestore({FirebaseFirestore? firestore, this.comprobantes})
    : db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<EstadoPremium> cargar(String uid) async {
    final (config, usuario, pagos) = await (
      db.collection('config').doc('academia').get(),
      db.collection('usuarios').doc(uid).get(),
      db.collection('pagos').where('usuarioId', isEqualTo: uid).get(),
    ).wait;
    final hasta = usuario.data()?['premiumHasta'];
    return EstadoPremium(
      configuracion: ConfiguracionAcademia.desdeMapa(config.data()),
      premiumHasta: hasta is Timestamp ? hasta.toDate() : null,
      pagos: [for (final d in pagos.docs) ?pagoDesdeMapa(d.id, d.data())]
        ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn)),
    );
  }

  @override
  Future<Cupon?> cupon(String codigo, DateTime ahora) async {
    final limpio = normalizarCodigo(codigo);
    if (limpio.isEmpty) return null;
    try {
      final d = await db.collection('cupones').doc(limpio).get();
      final c = d.exists ? cuponDesdeMapa(d.id, d.data()!) : null;
      return c != null && c.vigente(ahora) ? c : null;
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<void> enviarPago({
    required String uid,
    required String nombre,
    required String correo,
    required MetodoPago metodo,
    required String operacion,
    required int monto,
    String? cupon,
    Uint8List? foto,
  }) async {
    final id = idPago(
      metodo: metodo,
      operacion: operacion,
      uid: uid,
      cupon: cupon,
    );
    String? fotoUrl;
    final servicio = comprobantes;
    if (foto != null && servicio != null) {
      fotoUrl = await servicio.subir(uid: uid, pagoId: id, bytes: foto);
    }
    try {
      // Si el documento ya existe (esa operación ya se registró), las
      // reglas lo rechazan: nadie puede reclamar la misma operación dos veces.
      await db.collection('pagos').doc(id).set({
        'usuarioId': uid,
        'nombre': nombre,
        'correo': correo,
        'monto': monto,
        'metodo': metodo.name,
        'operacion': normalizarOperacion(operacion),
        'cupon': ?cupon,
        'estado': EstadoPago.pendiente.name,
        'creadoEn': FieldValue.serverTimestamp(),
        'fotoUrl': ?fotoUrl,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError(
          metodo == MetodoPago.beca
              ? 'Ya canjeaste este cupón.'
              : 'Ese N.º de operación ya fue registrado. Revisa el número '
                    'o escríbenos por WhatsApp.',
        );
      }
      rethrow;
    }
  }
}
