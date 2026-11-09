import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/teachers/domain/clase_docente.dart';
import '../../features/teachers/infrastructure/repositorio_clases_docente_firestore.dart';
import '../registro_admin.dart';

/// Clases que envían los docentes: el administrador las ve y decide si
/// los alumnos las ven.
abstract class RepositorioClasesDocentesAdmin {
  /// Cuántas esperan revisión, en vivo (para el menú lateral).
  Stream<int> pendientes();

  Future<List<ClaseDocente>> clases(EstadoClaseDocente estado);

  Future<void> publicar(ClaseDocente clase);

  /// No la publica, o la oculta si ya estaba publicada.
  Future<void> rechazar(ClaseDocente clase, String motivo);
}

class RepositorioClasesDocentesAdminFirestore
    implements RepositorioClasesDocentesAdmin {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  RepositorioClasesDocentesAdminFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _clases =>
      db.collection('clases_docente');

  @override
  Stream<int> pendientes() => _clases
      .where('estado', isEqualTo: EstadoClaseDocente.pendiente.name)
      .snapshots()
      .map((q) => q.size);

  @override
  Future<List<ClaseDocente>> clases(EstadoClaseDocente estado) async {
    final q = await _clases.where('estado', isEqualTo: estado.name).get();
    final lista = [for (final d in q.docs) ?claseDesdeMapa(d.id, d.data())];
    return estado == EstadoClaseDocente.aprobada
        ? ordenarPorCorazones(lista)
        : (lista..sort((a, b) => b.creadaEn.compareTo(a.creadaEn)));
  }

  Future<void> _cambiar(
    ClaseDocente c,
    EstadoClaseDocente estado,
    String? motivo,
    String accion,
  ) async {
    final lote = db.batch()
      ..update(_clases.doc(c.id), {
        'estado': estado.name,
        'motivo': motivo ?? FieldValue.delete(),
        'revisadoPor': correoAdmin(auth),
        'revisadaEn': FieldValue.serverTimestamp(),
      })
      ..set(
        db.collection('registro_admin').doc(),
        entradaRegistro(
          auth,
          tipo: 'docente',
          usuarioId: c.docenteUid,
          descripcion: '$accion la clase "${c.titulo}" de ${c.docenteNombre}',
        ),
      );
    await lote.commit();
  }

  @override
  Future<void> publicar(ClaseDocente c) =>
      _cambiar(c, EstadoClaseDocente.aprobada, null, 'Publicó');

  @override
  Future<void> rechazar(ClaseDocente c, String motivo) => _cambiar(
    c,
    EstadoClaseDocente.rechazada,
    motivo,
    c.estado == EstadoClaseDocente.aprobada ? 'Ocultó' : 'No publicó',
  );
}
