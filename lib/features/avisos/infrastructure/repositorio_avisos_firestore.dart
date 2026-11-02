import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/aviso.dart';

class RepositorioAvisosFirestore implements RepositorioAvisos {
  final FirebaseFirestore db;

  RepositorioAvisosFirestore({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Aviso>> activos() async {
    // Las reglas solo dejan leer al estudiante los avisos activos.
    final q = await db
        .collection('avisos')
        .where('activo', isEqualTo: true)
        .get();
    return [for (final d in q.docs) ?avisoDesdeMapa(d.id, d.data())];
  }
}

Aviso? avisoDesdeMapa(String id, Map<String, dynamic> m) {
  final titulo = m['titulo'];
  final hasta = m['hasta'];
  if (titulo is! String || hasta is! Timestamp) return null;
  return Aviso(
    id: id,
    titulo: titulo,
    mensaje: (m['mensaje'] as String?) ?? '',
    hasta: hasta.toDate(),
    versionId: m['versionId'] as String?,
    importante: m['importante'] == true,
    activo: m['activo'] == true,
    creadoEn: (m['creadoEn'] as Timestamp?)?.toDate(),
  );
}
