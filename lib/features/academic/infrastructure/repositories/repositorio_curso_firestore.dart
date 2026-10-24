import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/curso.dart';
import '../../domain/repositories/repositorio_curso.dart';

class RepositorioCursoFirestore implements RepositorioCurso {
  final FirebaseFirestore firestore;

  RepositorioCursoFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Curso>> obtenerActivos() async {
    final consulta = await firestore
        .collection('cursos')
        .where('activo', isEqualTo: true)
        .get();

    final cursos = consulta.docs.map((documento) {
      final datos = documento.data();

      return Curso(
        id: documento.id,
        areaId: datos['areaId'] as String,
        nombre: datos['nombre'] as String,
        orden: datos['orden'] as int,
        icono: datos['icono'] as String?,
        activo: datos['activo'] as bool,
      );
    }).toList();

    cursos.sort((a, b) => a.orden.compareTo(b.orden));

    return cursos;
  }
}
