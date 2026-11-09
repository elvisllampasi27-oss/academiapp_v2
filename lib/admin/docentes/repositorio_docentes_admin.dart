import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/teachers/domain/solicitud_docente.dart';
import '../../features/teachers/infrastructure/repositorio_docentes_firestore.dart';
import '../registro_admin.dart';

/// Solicitudes de cuenta de docente: el administrador revisa el canal o
/// las redes y aprueba (crea docentes/{uid}) o no.
abstract class RepositorioDocentesAdmin {
  /// Cuántas esperan revisión, en vivo (para el menú lateral).
  Stream<int> pendientes();

  Future<List<SolicitudDocente>> solicitudes(EstadoSolicitudDocente estado);

  Future<void> aprobar(SolicitudDocente solicitud);

  Future<void> rechazar(SolicitudDocente solicitud, String motivo);

  /// Quita la cuenta a un docente ya aprobado.
  Future<void> retirar(SolicitudDocente solicitud, String motivo);
}

class RepositorioDocentesAdminFirestore implements RepositorioDocentesAdmin {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  RepositorioDocentesAdminFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _solicitudes =>
      db.collection('solicitudes_docente');

  @override
  Stream<int> pendientes() => _solicitudes
      .where('estado', isEqualTo: EstadoSolicitudDocente.pendiente.name)
      .snapshots()
      .map((q) => q.size);

  @override
  Future<List<SolicitudDocente>> solicitudes(
    EstadoSolicitudDocente estado,
  ) async {
    final q = await _solicitudes.where('estado', isEqualTo: estado.name).get();
    return [for (final d in q.docs) ?solicitudDesdeMapa(d.id, d.data())]
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  Map<String, Object?> _revision(
    EstadoSolicitudDocente estado,
    String? motivo,
  ) => {
    'estado': estado.name,
    'motivo': motivo ?? FieldValue.delete(),
    'revisadoPor': correoAdmin(auth),
    'revisadaEn': FieldValue.serverTimestamp(),
  };

  void _registrar(WriteBatch lote, SolicitudDocente s, String accion) =>
      lote.set(
        db.collection('registro_admin').doc(),
        entradaRegistro(
          auth,
          tipo: 'docente',
          usuarioId: s.uid,
          descripcion: '$accion la cuenta de docente de ${s.nombre}',
        ),
      );

  @override
  Future<void> aprobar(SolicitudDocente s) async {
    final lote = db.batch()
      ..update(
        _solicitudes.doc(s.uid),
        _revision(EstadoSolicitudDocente.aprobada, null),
      )
      ..set(db.collection('docentes').doc(s.uid), {
        'uid': s.uid,
        'nombre': s.nombre,
        'correo': s.correo,
        'cursos': s.cursos,
        'enlaces': s.enlaces,
        'activo': true,
        'aprobadoEn': FieldValue.serverTimestamp(),
        'aprobadoPor': correoAdmin(auth),
      });
    _registrar(lote, s, 'Aprobó');
    await lote.commit();
  }

  @override
  Future<void> rechazar(SolicitudDocente s, String motivo) async {
    final lote = db.batch()
      ..update(
        _solicitudes.doc(s.uid),
        _revision(EstadoSolicitudDocente.rechazada, motivo),
      );
    _registrar(lote, s, 'No aprobó');
    await lote.commit();
  }

  /// También oculta sus clases y en vivos aprobados (en lotes).
  @override
  Future<void> retirar(SolicitudDocente s, String motivo) async {
    final (clases, enVivos) = await (
      db
          .collection('clases_docente')
          .where('docenteUid', isEqualTo: s.uid)
          .where('estado', isEqualTo: 'aprobada')
          .get(),
      db
          .collection('en_vivos')
          .where('docenteUid', isEqualTo: s.uid)
          .where('estado', isEqualTo: 'aprobado')
          .get(),
    ).wait;

    final lote = db.batch()
      ..update(
        _solicitudes.doc(s.uid),
        _revision(EstadoSolicitudDocente.rechazada, motivo),
      )
      ..delete(db.collection('docentes').doc(s.uid));
    _registrar(lote, s, 'Retiró');
    await lote.commit();

    final ocultar = [
      for (final d in clases.docs) (d.reference, 'rechazada'),
      for (final d in enVivos.docs) (d.reference, 'rechazado'),
    ];
    for (var i = 0; i < ocultar.length; i += 400) {
      final lote = db.batch();
      for (final (ref, estado) in ocultar.skip(i).take(400)) {
        lote.update(ref, {
          'estado': estado,
          'motivo': 'Se retiró la cuenta del docente.',
          'revisadoPor': correoAdmin(auth),
        });
      }
      await lote.commit();
    }
  }
}
