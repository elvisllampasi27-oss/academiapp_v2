import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/plan_academico.dart';
import '../../domain/repositories/repositorio_plan_academico.dart';

class RepositorioPlanAcademicoFirestore implements RepositorioPlanAcademico {
  final FirebaseFirestore firestore;

  RepositorioPlanAcademicoFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<PlanAcademico?> buscarActivoPorVersionId(String versionId) async {
    final consulta = await firestore
        .collection('planes_academicos')
        .where('versionId', isEqualTo: versionId)
        .where('activo', isEqualTo: true)
        .limit(1)
        .get();

    if (consulta.docs.isEmpty) {
      return null;
    }

    final documento = consulta.docs.first;
    final datos = documento.data();

    return PlanAcademico(
      id: documento.id,
      versionId: datos['versionId'] as String,
      nombre: datos['nombre'] as String,
      activo: datos['activo'] as bool,
    );
  }
}
