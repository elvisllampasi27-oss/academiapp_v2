import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tema.dart';
import '../../domain/repositories/repositorio_tema.dart';

class RepositorioTemaFirestore implements RepositorioTema {
  final FirebaseFirestore firestore;

  RepositorioTemaFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Tema>> obtenerActivos() async {
    final consulta = await firestore
        .collection('temas')
        .where('activo', isEqualTo: true)
        .get();

    return consulta.docs.map((documento) {
      final datos = documento.data();

      return Tema(
        id: documento.id,
        cursoId: datos['cursoId'] as String,
        titulo: datos['titulo'] as String,
        orden: datos['orden'] as int,
        descripcion: datos['descripcion'] as String?,
        activo: datos['activo'] as bool,
      );
    }).toList();
  }
}
