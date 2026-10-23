import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/version_academica.dart';
import '../../domain/repositories/repositorio_version_academica.dart';

class RepositorioVersionAcademicaFirestore
    implements RepositorioVersionAcademica {
  final FirebaseFirestore firestore;

  RepositorioVersionAcademicaFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<VersionAcademica?> buscarPorId(String versionId) async {
    final documento = await firestore
        .collection('versiones_academicas')
        .doc(versionId)
        .get();

    if (!documento.exists) {
      return null;
    }

    final datos = documento.data()!;

    return VersionAcademica(
      id: documento.id,
      codigo: datos['codigo'] as String,
      nombre: datos['nombre'] as String,
      fechaApertura: (datos['fechaApertura'] as Timestamp).toDate(),
      fechaCorte: datos['fechaCorte'] == null
          ? null
          : (datos['fechaCorte'] as Timestamp).toDate(),
      estado: _convertirEstado(datos['estado'] as String),
    );
  }

  EstadoVersionAcademica _convertirEstado(String estado) {
    return switch (estado) {
      'preparacion' => EstadoVersionAcademica.preparacion,
      'publicada' => EstadoVersionAcademica.publicada,
      'activa' => EstadoVersionAcademica.activa,
      'cerradaNuevasMatriculas' =>
        EstadoVersionAcademica.cerradaNuevasMatriculas,
      'finalizada' => EstadoVersionAcademica.finalizada,
      'archivada' => EstadoVersionAcademica.archivada,
      _ => throw StateError('Estado de version academica desconocido: $estado'),
    };
  }
}
