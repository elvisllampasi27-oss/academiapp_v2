import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/evidencia.dart';
import '../../domain/repositories/repositorio_evidencia.dart';

class RepositorioEvidenciaFirestore implements RepositorioEvidencia {
  final FirebaseFirestore firestore;

  RepositorioEvidenciaFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<RegistroEvidencias> obtenerDeMatricula({
    required String usuarioId,
    required String matriculaId,
  }) async {
    // El filtro por usuarioId es obligatorio: las reglas solo permiten
    // leer las evidencias propias.
    final consulta = await firestore
        .collection('evidencias')
        .where('usuarioId', isEqualTo: usuarioId)
        .where('matriculaId', isEqualTo: matriculaId)
        .get();

    final evidencias = <Evidencia>[];
    final temaPorHabilidad = <String, String>{};

    for (final documento in consulta.docs) {
      final datos = documento.data();
      final origen = OrigenEvidencia.values.asNameMap()[datos['origen']];
      final resultado = ResultadoEvidencia.values
          .asNameMap()[datos['resultado']];
      final dificultad =
          DificultadEvidencia.values.asNameMap()[datos['dificultad']] ??
          DificultadEvidencia.basica;

      if (origen == null || resultado == null) continue;

      final habilidadId = datos['habilidadId'] as String;
      final temaId = datos['temaId'] as String?;
      if (temaId != null) temaPorHabilidad[habilidadId] = temaId;

      evidencias.add(
        Evidencia(
          id: documento.id,
          matriculaId: datos['matriculaId'] as String,
          respuestaId: datos['respuestaId'] as String,
          habilidadId: habilidadId,
          origen: origen,
          resultado: resultado,
          dificultad: dificultad,
          numeroIntento: (datos['numeroIntento'] as num?)?.toInt() ?? 1,
          ayudaUtilizada: datos['ayudaUtilizada'] == true,
          fecha: (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ),
      );
    }

    return RegistroEvidencias(
      evidencias: evidencias,
      temaPorHabilidad: temaPorHabilidad,
    );
  }
}
