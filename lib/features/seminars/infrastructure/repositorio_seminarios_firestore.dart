import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/seminario.dart';

class RepositorioSeminariosFirestore implements RepositorioSeminarios {
  final FirebaseFirestore firestore;

  RepositorioSeminariosFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Seminario>> listar() async {
    final consulta = await firestore
        .collection('seminarios')
        .where('activo', isEqualTo: true)
        .get();

    return [for (final d in consulta.docs) ?seminarioDesdeMapa(d.id, d.data())];
  }
}

Seminario? seminarioDesdeMapa(String id, Map<String, dynamic> datos) {
  final fecha = datos['fecha'];
  final videoId = datos['videoId'];
  if (fecha is! Timestamp || videoId is! String || videoId.isEmpty) {
    return null;
  }

  return Seminario(
    id: id,
    titulo: datos['titulo'] as String? ?? 'Seminario',
    curso: datos['cursoNombre'] as String?,
    fecha: fecha.toDate(),
    videoId: videoId,
    duracionMinutos: (datos['duracionMinutos'] as num?)?.toInt() ?? 90,
  );
}
