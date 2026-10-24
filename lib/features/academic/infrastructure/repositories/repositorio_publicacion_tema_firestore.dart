import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/publicacion_tema.dart';
import '../../domain/repositories/repositorio_publicacion_tema.dart';

class RepositorioPublicacionTemaFirestore
    implements RepositorioPublicacionTema {
  final FirebaseFirestore firestore;

  RepositorioPublicacionTemaFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<PublicacionTema>> obtenerPublicadasPorVersionId(
    String versionId,
  ) async {
    final consulta = await firestore
        .collection('publicaciones_temas')
        .where('versionId', isEqualTo: versionId)
        .where('publicada', isEqualTo: true)
        .get();

    return consulta.docs.map((documento) {
      final datos = documento.data();

      return PublicacionTema(
        id: documento.id,
        versionId: datos['versionId'] as String,
        temaId: datos['temaId'] as String,
        publicada: datos['publicada'] as bool,
      );
    }).toList();
  }
}
