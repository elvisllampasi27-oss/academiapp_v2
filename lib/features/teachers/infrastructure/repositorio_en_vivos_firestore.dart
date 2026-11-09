import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/en_vivo.dart';

class RepositorioEnVivosFirestore implements RepositorioEnVivos {
  final FirebaseFirestore firestore;
  final DateTime Function() ahora;

  RepositorioEnVivosFirestore({
    FirebaseFirestore? firestore,
    this.ahora = DateTime.now,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _enVivos =>
      firestore.collection('en_vivos');

  List<EnVivo> _leer(QuerySnapshot<Map<String, dynamic>> q) => [
    for (final d in q.docs) ?enVivoDesdeMapa(d.id, d.data()),
  ];

  @override
  Future<List<EnVivo>> vigentes() async {
    // Índice compuesto (estado, fin) en firestore.indexes.json.
    final q = await _enVivos
        .where('estado', isEqualTo: EstadoEnVivo.aprobado.name)
        .where('fin', isGreaterThan: Timestamp.fromDate(ahora()))
        .get();
    return paraMostrar(_leer(q), ahora());
  }

  @override
  Future<List<EnVivo>> delDocente(String docenteUid) async {
    final q = await _enVivos
        .where('docenteUid', isEqualTo: docenteUid)
        .where('estado', isEqualTo: EstadoEnVivo.aprobado.name)
        .get();
    return paraMostrar(_leer(q), ahora());
  }

  @override
  Future<List<EnVivo>> mios(String docenteUid) async {
    final q = await _enVivos.where('docenteUid', isEqualTo: docenteUid).get();
    return _leer(q)..sort((a, b) => b.inicio.compareTo(a.inicio));
  }

  @override
  Future<void> programar({
    required String docenteUid,
    required String docenteNombre,
    required String titulo,
    required PlataformaEnVivo plataforma,
    required String enlace,
    required DateTime inicio,
    required int duracionMinutos,
    String? cursoNombre,
  }) {
    // Las reglas exigen fin = inicio + duración, en minutos exactos.
    final empieza = DateTime(
      inicio.year,
      inicio.month,
      inicio.day,
      inicio.hour,
      inicio.minute,
    );
    final curso = cursoNombre?.trim() ?? '';
    return _enVivos.add({
      'docenteUid': docenteUid,
      'docenteNombre': docenteNombre.trim(),
      'titulo': titulo.trim(),
      'plataforma': plataforma.name,
      'enlace': enlace.trim(),
      'inicio': Timestamp.fromDate(empieza),
      'fin': Timestamp.fromDate(
        empieza.add(Duration(minutes: duracionMinutos)),
      ),
      'duracionMinutos': duracionMinutos,
      'cursoNombre': curso,
      'estado': EstadoEnVivo.pendiente.name,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> cancelar(EnVivo enVivo) => _enVivos.doc(enVivo.id).delete();
}

EnVivo? enVivoDesdeMapa(String id, Map<String, dynamic> d) {
  final plataforma = PlataformaEnVivo.desde(d['plataforma']);
  final estado = EstadoEnVivo.desde(d['estado']);
  final inicio = d['inicio'];
  final fin = d['fin'];
  final docenteUid = d['docenteUid'];
  final enlace = d['enlace'];
  if (plataforma == null || estado == null) return null;
  if (inicio is! Timestamp || fin is! Timestamp) return null;
  if (docenteUid is! String || enlace is! String) return null;
  final curso = (d['cursoNombre'] as String?)?.trim() ?? '';
  final motivo = (d['motivo'] as String?)?.trim() ?? '';

  return EnVivo(
    id: id,
    docenteUid: docenteUid,
    docenteNombre: d['docenteNombre'] as String? ?? 'Docente',
    titulo: d['titulo'] as String? ?? 'En vivo',
    plataforma: plataforma,
    enlace: enlace,
    inicio: inicio.toDate(),
    fin: fin.toDate(),
    estado: estado,
    cursoNombre: curso.isEmpty ? null : curso,
    motivo: motivo.isEmpty ? null : motivo,
  );
}
