import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/premium/domain/configuracion_academia.dart';
import '../../features/premium/domain/cupon.dart';
import '../../features/premium/domain/pago.dart';
import '../../features/premium/infrastructure/premium_desde_mapa.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../registro_admin.dart';
import 'repositorio_pagos_admin.dart';

class RepositorioPagosAdminFirestore
    implements RepositorioPagosAdmin, RepositorioAcademiaAdmin {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  RepositorioPagosAdminFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _pagos =>
      db.collection('pagos');

  // ------------------------------------------------------------ pagos

  @override
  Stream<int> pendientes() => _pagos
      .where('estado', isEqualTo: EstadoPago.pendiente.name)
      .snapshots()
      .map((q) => q.size);

  @override
  Future<List<Pago>> pagos(EstadoPago estado) async {
    final q = await _pagos.where('estado', isEqualTo: estado.name).get();
    return _ordenar(q);
  }

  @override
  Future<List<Pago>> pagosDe(String uid) async {
    final q = await _pagos.where('usuarioId', isEqualTo: uid).get();
    return _ordenar(q);
  }

  List<Pago> _ordenar(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) ?pagoDesdeMapa(d.id, d.data())]
        ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));

  @override
  Future<DateTime> aprobar(Pago pago, {required int dias}) {
    return db.runTransaction((tx) async {
      final pagoRef = _pagos.doc(pago.id);
      final usuarioRef = db.collection('usuarios').doc(pago.usuarioId);
      final actualPago = await tx.get(pagoRef);
      final usuario = await tx.get(usuarioRef);
      if (actualPago.data()?['estado'] != EstadoPago.pendiente.name) {
        throw StateError('Este pago ya fue revisado. Actualiza la lista.');
      }

      final anterior = (usuario.data()?['premiumHasta'] as Timestamp?)
          ?.toDate();
      final nuevo = premiumNuevoHasta(anterior, DateTime.now(), dias);

      tx.update(usuarioRef, {'premiumHasta': Timestamp.fromDate(nuevo)});
      tx.update(pagoRef, {
        'estado': EstadoPago.aprobado.name,
        'revisadoEn': FieldValue.serverTimestamp(),
        'revisadoPor': correoAdmin(auth),
        'premiumHasta': Timestamp.fromDate(nuevo),
        'premiumAnterior': anterior == null
            ? null
            : Timestamp.fromDate(anterior),
      });
      if (pago.cupon case final codigo?) {
        tx.set(db.collection('cupones').doc(codigo), {
          'usos': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
      tx.set(
        db.collection('registro_admin').doc(),
        entradaRegistro(
          auth,
          tipo: 'pago',
          usuarioId: pago.usuarioId,
          descripcion:
              'Aprobó el pago de ${pago.nombre} (${_detalle(pago)}): '
              'Premium hasta el ${fechaPanel(nuevo)}',
        ),
      );
      return nuevo;
    });
  }

  @override
  Future<void> rechazar(Pago pago, {required String motivo}) async {
    final lote = db.batch();
    lote.update(_pagos.doc(pago.id), {
      'estado': EstadoPago.rechazado.name,
      'revisadoEn': FieldValue.serverTimestamp(),
      'revisadoPor': correoAdmin(auth),
      'motivo': motivo,
    });
    lote.set(
      db.collection('registro_admin').doc(),
      entradaRegistro(
        auth,
        tipo: 'pago',
        usuarioId: pago.usuarioId,
        descripcion:
            'Rechazó el pago de ${pago.nombre} (${_detalle(pago)}): $motivo',
      ),
    );
    await lote.commit();
  }

  @override
  Future<void> revertir(Pago pago) {
    return db.runTransaction((tx) async {
      final pagoRef = _pagos.doc(pago.id);
      final usuarioRef = db.collection('usuarios').doc(pago.usuarioId);
      final actualPago = await tx.get(pagoRef);
      final usuario = await tx.get(usuarioRef);
      final estado = actualPago.data()?['estado'];

      if (estado == EstadoPago.aprobado.name) {
        // Solo se deshace si este fue el último Premium que se le dio.
        final vigente = (usuario.data()?['premiumHasta'] as Timestamp?)
            ?.millisecondsSinceEpoch;
        final delPago = (actualPago.data()?['premiumHasta'] as Timestamp?)
            ?.millisecondsSinceEpoch;
        if (vigente != delPago) {
          throw StateError(
            'Después de este pago se le dio más Premium. Revierte primero '
            'el más reciente.',
          );
        }
        final anterior = actualPago.data()?['premiumAnterior'];
        tx.update(usuarioRef, {
          'premiumHasta': anterior ?? FieldValue.delete(),
        });
        if (pago.cupon case final codigo?) {
          tx.set(db.collection('cupones').doc(codigo), {
            'usos': FieldValue.increment(-1),
          }, SetOptions(merge: true));
        }
      } else if (estado != EstadoPago.rechazado.name) {
        throw StateError('Este pago ya está por revisar.');
      }

      tx.update(pagoRef, {
        'estado': EstadoPago.pendiente.name,
        'revisadoEn': FieldValue.delete(),
        'revisadoPor': FieldValue.delete(),
        'motivo': FieldValue.delete(),
        'premiumHasta': FieldValue.delete(),
        'premiumAnterior': FieldValue.delete(),
      });
      tx.set(
        db.collection('registro_admin').doc(),
        entradaRegistro(
          auth,
          tipo: 'pago',
          usuarioId: pago.usuarioId,
          descripcion:
              'Revirtió el pago de ${pago.nombre} (${_detalle(pago)}): '
              'vuelve a "por revisar"',
        ),
      );
    });
  }

  @override
  Future<DateTime> darPremium({
    required String uid,
    required String nombre,
    required String correo,
    required int dias,
    required String motivo,
  }) {
    return db.runTransaction((tx) async {
      final usuarioRef = db.collection('usuarios').doc(uid);
      final usuario = await tx.get(usuarioRef);
      final anterior = (usuario.data()?['premiumHasta'] as Timestamp?)
          ?.toDate();
      final ahora = DateTime.now();
      final nuevo = premiumNuevoHasta(anterior, ahora, dias);

      tx.update(usuarioRef, {'premiumHasta': Timestamp.fromDate(nuevo)});
      tx.set(_pagos.doc('manual__${uid}__${ahora.millisecondsSinceEpoch}'), {
        'usuarioId': uid,
        'nombre': nombre,
        'correo': correo,
        'monto': 0,
        'metodo': MetodoPago.manual.name,
        'operacion': '',
        'estado': EstadoPago.aprobado.name,
        'motivo': motivo,
        'creadoEn': FieldValue.serverTimestamp(),
        'revisadoEn': FieldValue.serverTimestamp(),
        'revisadoPor': correoAdmin(auth),
        'premiumHasta': Timestamp.fromDate(nuevo),
        'premiumAnterior': anterior == null
            ? null
            : Timestamp.fromDate(anterior),
      });
      tx.set(
        db.collection('registro_admin').doc(),
        entradaRegistro(
          auth,
          tipo: 'premium',
          usuarioId: uid,
          descripcion:
              'Dio $dias días de Premium a $nombre ($motivo): hasta el '
              '${fechaPanel(nuevo)}',
        ),
      );
      return nuevo;
    });
  }

  String _detalle(Pago p) => switch (p.metodo) {
    MetodoPago.beca => 'beca ${p.cupon}',
    MetodoPago.manual => 'manual',
    _ => 'S/ ${p.monto} · ${p.metodo.etiqueta} · N.º ${p.operacion}',
  };

  // ---------------------------------------------- configuración y cupones

  @override
  Future<ConfiguracionAcademia> configuracion() async {
    final d = await db.collection('config').doc('academia').get();
    return ConfiguracionAcademia.desdeMapa(d.data());
  }

  @override
  Future<void> guardarConfiguracion(ConfiguracionAcademia c) async {
    final lote = db.batch();
    lote.set(db.collection('config').doc('academia'), c.aMapa());
    lote.set(
      db.collection('registro_admin').doc(),
      entradaRegistro(
        auth,
        tipo: 'configuracion',
        descripcion:
            'Cambió la configuración: S/ ${c.precio} por ${c.diasPremium} '
            'días, tutor ${c.tutorGratis}/${c.tutorPremium} al día',
      ),
    );
    await lote.commit();
  }

  @override
  Future<List<Cupon>> cupones() async {
    final q = await db.collection('cupones').get();
    return [for (final d in q.docs) ?cuponDesdeMapa(d.id, d.data())]
      ..sort((a, b) => a.codigo.compareTo(b.codigo));
  }

  @override
  Future<void> guardarCupon(Cupon cupon, {required bool nuevo}) {
    return db.runTransaction((tx) async {
      final ref = db.collection('cupones').doc(cupon.codigo);
      if (nuevo && (await tx.get(ref)).exists) {
        throw StateError('Ya existe un cupón ${cupon.codigo}.');
      }
      final datos = cuponAMapa(cupon);
      // Al editar no se pisa el contador de usos.
      if (!nuevo) datos.remove('usos');
      tx.set(ref, datos, SetOptions(merge: true));
      tx.set(
        db.collection('registro_admin').doc(),
        entradaRegistro(
          auth,
          tipo: 'cupon',
          descripcion:
              '${nuevo ? 'Creó' : 'Editó'} el cupón ${cupon.codigo} '
              '(${cupon.beneficio}${cupon.activo ? '' : ', desactivado'})',
        ),
      );
    });
  }

  @override
  Future<void> eliminarCupon(Cupon cupon) async {
    final lote = db.batch();
    lote.delete(db.collection('cupones').doc(cupon.codigo));
    lote.set(
      db.collection('registro_admin').doc(),
      entradaRegistro(
        auth,
        tipo: 'cupon',
        descripcion: 'Eliminó el cupón ${cupon.codigo} (${cupon.usos} usos)',
      ),
    );
    await lote.commit();
  }
}
