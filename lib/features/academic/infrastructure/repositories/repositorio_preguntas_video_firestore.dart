import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/pregunta_video.dart';
import '../../domain/repositories/repositorio_preguntas_video.dart';

/// `preguntas_video/{versionId}__{temaId}`: las lee cualquier alumno con
/// sesión y solo las escribe el administrador (ver firestore.rules).
class RepositorioPreguntasVideoFirestore implements RepositorioPreguntasVideo {
  final FirebaseFirestore db;

  RepositorioPreguntasVideoFirestore({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String versionId, String temaId) =>
      db.collection('preguntas_video').doc('${versionId}__$temaId');

  @override
  Future<List<PreguntaVideo>> delTema({
    required String versionId,
    required String temaId,
  }) async => preguntasVideoDesdeMapa((await _doc(versionId, temaId).get()).data());

  @override
  Future<void> guardar({
    required String versionId,
    required String temaId,
    required List<PreguntaVideo> preguntas,
  }) => _doc(versionId, temaId).set({
    'versionId': versionId,
    'temaId': temaId,
    'preguntas': [for (final p in preguntas) preguntaVideoAMapa(p)],
    'actualizadoEn': FieldValue.serverTimestamp(),
  });
}
