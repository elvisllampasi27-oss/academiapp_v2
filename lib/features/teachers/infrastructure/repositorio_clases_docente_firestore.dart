import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/clase_docente.dart';

class RepositorioClasesDocenteFirestore implements RepositorioClasesDocente {
  final FirebaseFirestore firestore;

  RepositorioClasesDocenteFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _clases =>
      firestore.collection('clases_docente');

  DocumentReference<Map<String, dynamic>> _corazon(
    String claseId,
    String uid,
  ) => _clases.doc(claseId).collection('corazones').doc(uid);

  @override
  Future<List<ClaseDocente>> delTema(String temaId) async {
    // Solo igualdades: no necesita índice compuesto.
    final q = await _clases
        .where('temaId', isEqualTo: temaId)
        .where('estado', isEqualTo: EstadoClaseDocente.aprobada.name)
        .get();
    return ordenarPorCorazones([
      for (final d in q.docs) ?claseDesdeMapa(d.id, d.data()),
    ]);
  }

  @override
  Future<Set<String>> conMiCorazon(String uid, List<String> claseIds) async {
    final docs = await Future.wait([
      for (final id in claseIds) _corazon(id, uid).get(),
    ]);
    return {
      for (final (i, d) in docs.indexed)
        if (d.exists) claseIds[i],
    };
  }

  // El contador y el corazón van juntos: las reglas exigen las dos cosas.
  @override
  Future<void> darCorazon(String claseId, String uid) =>
      (firestore.batch()
            ..update(_clases.doc(claseId), {
              'corazones': FieldValue.increment(1),
            })
            ..set(_corazon(claseId, uid), {
              'creadoEn': FieldValue.serverTimestamp(),
            }))
          .commit();

  @override
  Future<void> quitarCorazon(String claseId, String uid) =>
      (firestore.batch()
            ..update(_clases.doc(claseId), {
              'corazones': FieldValue.increment(-1),
            })
            ..delete(_corazon(claseId, uid)))
          .commit();

  @override
  Future<List<ClaseDocente>> deDocente(String docenteUid) async {
    final q = await _clases
        .where('docenteUid', isEqualTo: docenteUid)
        .where('estado', isEqualTo: EstadoClaseDocente.aprobada.name)
        .get();
    return ordenarPorCorazones([
      for (final d in q.docs) ?claseDesdeMapa(d.id, d.data()),
    ]);
  }

  @override
  Future<List<ClaseDocente>> mias(String docenteUid) async {
    final q = await _clases.where('docenteUid', isEqualTo: docenteUid).get();
    return [for (final d in q.docs) ?claseDesdeMapa(d.id, d.data())]
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  @override
  Future<void> enviar({
    required String docenteUid,
    required String docenteNombre,
    required String temaId,
    required String temaTitulo,
    required String cursoNombre,
    required String titulo,
    required String videoId,
  }) => _clases.add({
    'docenteUid': docenteUid,
    'docenteNombre': docenteNombre.trim(),
    'temaId': temaId,
    'temaTitulo': temaTitulo,
    'cursoNombre': cursoNombre,
    'titulo': titulo.trim(),
    'videoId': videoId,
    'estado': EstadoClaseDocente.pendiente.name,
    'corazones': 0,
    'creadaEn': FieldValue.serverTimestamp(),
  });
}

ClaseDocente? claseDesdeMapa(String id, Map<String, dynamic> d) {
  final estado = EstadoClaseDocente.desde(d['estado']);
  final videoId = d['videoId'];
  final temaId = d['temaId'];
  final docenteUid = d['docenteUid'];
  if (estado == null || videoId is! String || temaId is! String) return null;
  if (docenteUid is! String) return null;
  final creada = d['creadaEn'];
  final motivo = (d['motivo'] as String?)?.trim() ?? '';

  return ClaseDocente(
    id: id,
    docenteUid: docenteUid,
    docenteNombre: d['docenteNombre'] as String? ?? 'Docente',
    temaId: temaId,
    temaTitulo: d['temaTitulo'] as String? ?? '',
    cursoNombre: d['cursoNombre'] as String? ?? '',
    titulo: d['titulo'] as String? ?? 'Clase',
    videoId: videoId,
    estado: estado,
    corazones: (d['corazones'] as num?)?.toInt() ?? 0,
    // Recién enviada, la hora del servidor todavía no llegó.
    creadaEn: creada is Timestamp ? creada.toDate() : DateTime.now(),
    motivo: motivo.isEmpty ? null : motivo,
  );
}
