import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/contenido.dart';
import '../../domain/repositories/repositorio_contenido.dart';

class RepositorioContenidoFirestore implements RepositorioContenido {
  final FirebaseFirestore firestore;

  RepositorioContenidoFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Contenido>> obtenerActivosPorTema(String temaId) async {
    final consulta = await firestore
        .collection('contenidos')
        .where('temaId', isEqualTo: temaId)
        .where('activo', isEqualTo: true)
        .get();

    return consulta.docs.map((documento) {
      final datos = documento.data();

      return Contenido(
        id: documento.id,
        temaId: datos['temaId'] as String,
        nombre: datos['nombre'] as String,
        descripcion: datos['descripcion'] as String?,
        orden: datos['orden'] as int,
        activo: datos['activo'] as bool,
      );
    }).toList();
  }
}
