import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/narracion.dart';

class RepositorioNarracionesFirestore implements RepositorioNarraciones {
  final FirebaseFirestore firestore;

  RepositorioNarracionesFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Narracion>> delTema({
    required String versionId,
    required String temaId,
  }) async {
    // Solo igualdades: no necesita índice compuesto. Se ordena aquí.
    final consulta = await firestore
        .collection('narraciones')
        .where('versionId', isEqualTo: versionId)
        .where('temaId', isEqualTo: temaId)
        .get();

    return ordenarNarraciones([
      for (final d in consulta.docs) ?narracionDesdeMapa(d.id, d.data()),
    ]);
  }
}

Narracion? narracionDesdeMapa(String id, Map<String, dynamic> datos) {
  final url = datos['url'];
  final versionId = datos['versionId'];
  final temaId = datos['temaId'];
  if (url is! String || url.isEmpty) return null;
  if (versionId is! String || temaId is! String) return null;

  final tipo = (datos['tipo'] as String?)?.trim() ?? '';
  final descripcion = (datos['descripcion'] as String?)?.trim() ?? '';
  final creada = datos['creada'];

  return Narracion(
    id: id,
    versionId: versionId,
    temaId: temaId,
    titulo: datos['titulo'] as String? ?? 'Narración',
    tipo: tipo.isEmpty ? 'Narración' : tipo,
    url: url,
    descripcion: descripcion.isEmpty ? null : descripcion,
    rutaAudio: datos['rutaAudio'] as String?,
    creada: creada is Timestamp ? creada.toDate() : null,
  );
}
