import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/avisos/domain/aviso.dart';
import '../../features/avisos/infrastructure/repositorio_avisos_firestore.dart';
import '../registro_admin.dart';

/// Avisos para los estudiantes. Cada cambio queda en el registro.
abstract class RepositorioAvisosAdmin {
  Future<List<Aviso>> avisos();

  /// Crea (si [nuevo]) o reemplaza el aviso.
  Future<void> guardar(Aviso aviso, {required bool nuevo});

  Future<void> eliminar(Aviso aviso);
}

class RepositorioAvisosAdminFirestore implements RepositorioAvisosAdmin {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  RepositorioAvisosAdminFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _avisos =>
      db.collection('avisos');

  @override
  Future<List<Aviso>> avisos() async {
    final q = await _avisos.get();
    final epoca = DateTime(2000);
    return [for (final d in q.docs) ?avisoDesdeMapa(d.id, d.data())]
      ..sort((a, b) => (b.creadoEn ?? epoca).compareTo(a.creadoEn ?? epoca));
  }

  @override
  Future<void> guardar(Aviso aviso, {required bool nuevo}) async {
    final ref = nuevo ? _avisos.doc() : _avisos.doc(aviso.id);
    final lote = db.batch();
    lote.set(ref, {
      'titulo': aviso.titulo,
      'mensaje': aviso.mensaje,
      // Siempre se escribe (null = para todos) para poder cambiarlo.
      'versionId': aviso.versionId,
      'importante': aviso.importante,
      'activo': aviso.activo,
      'hasta': Timestamp.fromDate(aviso.hasta),
      if (nuevo) 'creadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    lote.set(
      db.collection('registro_admin').doc(),
      entradaRegistro(
        auth,
        tipo: 'aviso',
        descripcion:
            '${nuevo ? 'Publicó' : 'Editó'} el aviso "${aviso.titulo}"',
      ),
    );
    await lote.commit();
  }

  @override
  Future<void> eliminar(Aviso aviso) async {
    final lote = db.batch();
    lote.delete(_avisos.doc(aviso.id));
    lote.set(
      db.collection('registro_admin').doc(),
      entradaRegistro(
        auth,
        tipo: 'aviso',
        descripcion: 'Eliminó el aviso "${aviso.titulo}"',
      ),
    );
    await lote.commit();
  }
}
