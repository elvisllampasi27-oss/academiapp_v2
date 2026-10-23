import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/matricula.dart';
import '../../domain/repositories/repositorio_matricula.dart';

class RepositorioMatriculaFirestore implements RepositorioMatricula {
  final FirebaseFirestore firestore;

  RepositorioMatriculaFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Matricula?> buscarActivaPorUsuarioId(String usuarioId) async {
    final consulta = await firestore
        .collection('matriculas')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('estado', isEqualTo: 'activa')
        .limit(1)
        .get();

    if (consulta.docs.isEmpty) {
      return null;
    }

    final documento = consulta.docs.first;
    final datos = documento.data();

    return Matricula(
      id: documento.id,
      usuarioId: datos['usuarioId'] as String,
      versionId: datos['versionId'] as String,
      fechaMatricula: (datos['fechaMatricula'] as Timestamp).toDate(),
      fechaInicioAcademico: (datos['fechaInicioAcademico'] as Timestamp)
          .toDate(),
      fechaFin: datos['fechaFin'] == null
          ? null
          : (datos['fechaFin'] as Timestamp).toDate(),
      estado: _convertirEstado(datos['estado'] as String),
    );
  }

  EstadoMatricula _convertirEstado(String estado) {
    return switch (estado) {
      'programada' => EstadoMatricula.programada,
      'activa' => EstadoMatricula.activa,
      'finalizada' => EstadoMatricula.finalizada,
      'suspendida' => EstadoMatricula.suspendida,
      _ => throw StateError('Estado de matricula desconocido: $estado'),
    };
  }
}
