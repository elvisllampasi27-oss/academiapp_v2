import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/reporte.dart';

class RepositorioReportesFirestore implements RepositorioReportes {
  final FirebaseFirestore db;

  RepositorioReportesFirestore({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> enviar({
    required String uid,
    required String nombre,
    required String correo,
    required TipoReporte tipo,
    required String mensaje,
    required ContextoReporte contexto,
  }) {
    return db.collection('reportes').add({
      'usuarioId': uid,
      'nombre': nombre,
      'correo': correo,
      'tipo': tipo.name,
      'mensaje': mensaje.trim(),
      'contexto': contexto.aMapa(),
      'estado': EstadoReporte.nuevo.name,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<Reporte>> mios(String uid) async {
    final q = await db
        .collection('reportes')
        .where('usuarioId', isEqualTo: uid)
        .get();
    return [for (final d in q.docs) ?reporteDesdeMapa(d.id, d.data())]
      ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
  }
}

Reporte? reporteDesdeMapa(String id, Map<String, dynamic> m) {
  final tipo = TipoReporte.values.asNameMap()[m['tipo']];
  final estado = EstadoReporte.values.asNameMap()[m['estado']];
  final usuarioId = m['usuarioId'];
  if (tipo == null || estado == null || usuarioId is! String) return null;
  return Reporte(
    id: id,
    usuarioId: usuarioId,
    nombre: (m['nombre'] as String?) ?? '',
    correo: (m['correo'] as String?) ?? '',
    tipo: tipo,
    mensaje: (m['mensaje'] as String?) ?? '',
    contexto: ContextoReporte.desdeMapa(
      (m['contexto'] as Map?)?.cast<String, dynamic>(),
    ),
    estado: estado,
    // Recién creado, la hora del servidor puede venir vacía un instante.
    creadoEn: (m['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
    respuesta: m['respuesta'] as String?,
    respondidoEn: (m['respondidoEn'] as Timestamp?)?.toDate(),
  );
}
