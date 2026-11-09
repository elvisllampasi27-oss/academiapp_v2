import 'package:cloud_firestore/cloud_firestore.dart';

import '../../academic/domain/entities/curriculo.dart';
import '../../academic/domain/repositories/repositorio_curriculo.dart';

/// Estados de una versión que todavía tiene alumnos estudiando.
const _vigentes = ['publicada', 'activa', 'cerradaNuevasMatriculas'];

/// Temario para que el docente elija el tema de su clase aunque no esté
/// matriculado: el de la versión vigente más reciente (los temas son los
/// mismos en todas las versiones). null si no hay ninguna.
Future<Curriculo?> leerTemarioVigente({
  required RepositorioCurriculo Function(String versionId) curriculoDe,
  FirebaseFirestore? firestore,
}) async {
  final q = await (firestore ?? FirebaseFirestore.instance)
      .collection('versiones_academicas')
      .where('estado', whereIn: _vigentes)
      .get();
  if (q.docs.isEmpty) return null;

  DateTime apertura(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final f = d.data()['fechaApertura'];
    return f is Timestamp ? f.toDate() : DateTime(2000);
  }

  final reciente = q.docs.reduce(
    (a, b) => apertura(a).isAfter(apertura(b)) ? a : b,
  );
  return curriculoDe(reciente.id).obtener();
}
