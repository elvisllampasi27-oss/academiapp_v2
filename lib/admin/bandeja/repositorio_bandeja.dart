import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/reportes/domain/reporte.dart';
import '../../features/reportes/infrastructure/repositorio_reportes_firestore.dart';
import '../registro_admin.dart';

/// Reportes que mandan los estudiantes desde la app.
abstract class RepositorioBandeja {
  /// Cuántos reportes nuevos hay, en vivo (para el menú lateral).
  Stream<int> nuevos();

  Future<List<Reporte>> reportes(EstadoReporte estado);

  /// Cambia el estado y, si hay [respuesta], el estudiante la ve en
  /// "Mis reportes".
  Future<void> cambiarEstado(
    Reporte reporte,
    EstadoReporte estado, {
    String? respuesta,
  });
}

class RepositorioBandejaFirestore implements RepositorioBandeja {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  RepositorioBandejaFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  @override
  Stream<int> nuevos() => db
      .collection('reportes')
      .where('estado', isEqualTo: EstadoReporte.nuevo.name)
      .snapshots()
      .map((q) => q.size);

  @override
  Future<List<Reporte>> reportes(EstadoReporte estado) async {
    final q = await db
        .collection('reportes')
        .where('estado', isEqualTo: estado.name)
        .get();
    return [for (final d in q.docs) ?reporteDesdeMapa(d.id, d.data())]
      ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
  }

  @override
  Future<void> cambiarEstado(
    Reporte reporte,
    EstadoReporte estado, {
    String? respuesta,
  }) async {
    final lote = db.batch();
    lote.update(db.collection('reportes').doc(reporte.id), {
      'estado': estado.name,
      if (respuesta != null) ...{
        'respuesta': respuesta,
        'respondidoEn': FieldValue.serverTimestamp(),
      },
      'revisadoPor': correoAdmin(auth),
    });
    final accion = switch (estado) {
      EstadoReporte.resuelto => 'Resolvió',
      EstadoReporte.enRevision => 'Tomó',
      EstadoReporte.nuevo => 'Reabrió',
    };
    lote.set(
      db.collection('registro_admin').doc(),
      entradaRegistro(
        auth,
        tipo: 'reporte',
        usuarioId: reporte.usuarioId,
        descripcion:
            '$accion el reporte de ${reporte.nombre} '
            '(${reporte.tipo.etiqueta.toLowerCase()})',
      ),
    );
    await lote.commit();
  }
}
