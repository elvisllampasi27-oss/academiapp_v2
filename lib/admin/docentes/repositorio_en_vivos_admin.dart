import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/teachers/domain/en_vivo.dart';
import '../../features/teachers/infrastructure/repositorio_en_vivos_firestore.dart';
import '../registro_admin.dart';

/// En vivos que programan los docentes: el administrador los aprueba (los
/// alumnos los ven en Inicio), no los aprueba o los termina antes.
abstract class RepositorioEnVivosAdmin {
  /// Cuántos esperan revisión, en vivo (para el menú lateral).
  Stream<int> pendientes();

  Future<List<EnVivo>> enVivos(EstadoEnVivo estado);

  Future<void> aprobar(EnVivo enVivo);

  Future<void> rechazar(EnVivo enVivo, String motivo);

  /// Lo termina ahora (deja de verse en la app).
  Future<void> terminar(EnVivo enVivo);
}

class RepositorioEnVivosAdminFirestore implements RepositorioEnVivosAdmin {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  RepositorioEnVivosAdminFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _enVivos =>
      db.collection('en_vivos');

  @override
  Stream<int> pendientes() => _enVivos
      .where('estado', isEqualTo: EstadoEnVivo.pendiente.name)
      .snapshots()
      .map((q) => q.size);

  @override
  Future<List<EnVivo>> enVivos(EstadoEnVivo estado) async {
    final q = await _enVivos.where('estado', isEqualTo: estado.name).get();
    return [for (final d in q.docs) ?enVivoDesdeMapa(d.id, d.data())]
      ..sort((a, b) => b.inicio.compareTo(a.inicio));
  }

  Future<void> _cambiar(
    EnVivo e,
    Map<String, Object?> cambios,
    String accion,
  ) async {
    final lote = db.batch()
      ..update(_enVivos.doc(e.id), {
        ...cambios,
        'revisadoPor': correoAdmin(auth),
        'revisadoEn': FieldValue.serverTimestamp(),
      })
      ..set(
        db.collection('registro_admin').doc(),
        entradaRegistro(
          auth,
          tipo: 'docente',
          usuarioId: e.docenteUid,
          descripcion: '$accion el en vivo "${e.titulo}" de ${e.docenteNombre}',
        ),
      );
    await lote.commit();
  }

  @override
  Future<void> aprobar(EnVivo e) => _cambiar(e, {
    'estado': EstadoEnVivo.aprobado.name,
    'motivo': FieldValue.delete(),
  }, 'Aprobó');

  @override
  Future<void> rechazar(EnVivo e, String motivo) => _cambiar(e, {
    'estado': EstadoEnVivo.rechazado.name,
    'motivo': motivo,
  }, e.estado == EstadoEnVivo.aprobado ? 'Quitó' : 'No aprobó');

  @override
  Future<void> terminar(EnVivo e) =>
      _cambiar(e, {'fin': FieldValue.serverTimestamp()}, 'Terminó');
}
