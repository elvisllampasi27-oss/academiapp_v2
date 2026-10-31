import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/progreso_clase.dart';
import '../../domain/repositories/repositorio_progreso_clase.dart';

/// Un documento por estudiante, versión y tema: `{uid}__{version}__{tema}`.
class RepositorioProgresoClaseFirestore implements RepositorioProgresoClase {
  final FirebaseFirestore firestore;

  RepositorioProgresoClaseFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _documento(
    String usuarioId,
    String versionId,
    String temaId,
  ) => firestore
      .collection('progreso_clases')
      .doc('${usuarioId}__${versionId}__$temaId');

  @override
  Future<ProgresoClase?> obtener({
    required String usuarioId,
    required String versionId,
    required String temaId,
  }) async {
    final documento = await _documento(usuarioId, versionId, temaId).get();
    final datos = documento.data();

    if (datos == null) return null;

    return ProgresoClase(
      temaId: temaId,
      versionId: versionId,
      tramos: datos.containsKey('tramos')
          ? tramosDesdeLista(datos['tramos'])
          // Documentos de la primera versión: solo "hasta dónde llegó".
          : [(0, (datos['posicionMaxima'] as num?)?.toDouble() ?? 0)],
      duracion: (datos['duracion'] as num?)?.toDouble() ?? 0,
      completada: datos['completada'] as bool? ?? false,
    );
  }

  @override
  Future<void> guardar({
    required String usuarioId,
    required ProgresoClase progreso,
  }) {
    return _documento(usuarioId, progreso.versionId, progreso.temaId).set({
      'usuarioId': usuarioId,
      'versionId': progreso.versionId,
      'temaId': progreso.temaId,
      // Firestore no admite listas de listas: se guarda plano.
      'tramos': [
        for (final (desde, hasta) in progreso.tramos) ...[desde, hasta],
      ],
      'duracion': progreso.duracion,
      'completada': progreso.completada,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }
}

/// [a1, b1, a2, b2, ...] → [(a1, b1), (a2, b2), ...]
List<(double, double)> tramosDesdeLista(Object? valor) {
  if (valor is! List) return const [];

  final numeros = [
    for (final v in valor)
      if (v is num) v.toDouble(),
  ];

  return [
    for (var i = 0; i + 1 < numeros.length; i += 2)
      (numeros[i], numeros[i + 1]),
  ];
}
