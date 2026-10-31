import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/recurso.dart';
import '../../domain/repositories/repositorio_recurso.dart';

class RepositorioRecursoFirestore implements RepositorioRecurso {
  final FirebaseFirestore firestore;

  RepositorioRecursoFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Recurso>> obtenerActivosPorTema({
    required String temaId,
    required String versionId,
  }) async {
    final consulta = await firestore
        .collection('recursos')
        .where('temaId', isEqualTo: temaId)
        .where('versionId', isEqualTo: versionId)
        .where('activo', isEqualTo: true)
        .get();

    final recursos = <Recurso>[];

    for (final documento in consulta.docs) {
      final datos = documento.data();
      final tipo = TipoRecurso.values.asNameMap()[datos['tipo']];

      // Un tipo desconocido (p. ej. agregado desde el panel en el futuro)
      // se ignora en vez de romper toda la pantalla.
      if (tipo == null) continue;

      recursos.add(
        Recurso(
          id: documento.id,
          temaId: datos['temaId'] as String,
          versionId: datos['versionId'] as String,
          tipo: tipo,
          titulo: datos['titulo'] as String,
          ubicacion: datos['ubicacion'] as String,
          activo: datos['activo'] as bool,
          reemplazaA: datos['reemplazaA'] as String?,
        ),
      );
    }

    return recursos;
  }
}
