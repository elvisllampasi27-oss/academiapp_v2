import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/academic/domain/entities/version_academica.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../registro_admin.dart';
import 'modelo_versiones.dart';
import 'repositorio_versiones_admin.dart';

class RepositorioVersionesAdminFirestore implements RepositorioVersionesAdmin {
  /// Firestore admite 500 escrituras por lote; se deja margen.
  static const _porLote = 450;

  final FirebaseFirestore db;
  final FirebaseAuth auth;

  RepositorioVersionesAdminFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _registro() =>
      db.collection('registro_admin').doc();

  @override
  Future<Set<String>> publicados(String versionId) async {
    final d = await db.collection('publicaciones_version').doc(versionId).get();
    return ((d.data()?['temas'] as List?) ?? const []).cast<String>().toSet();
  }

  @override
  Future<void> guardar(VersionAcademica v, {required String cambio}) async {
    final lote = db.batch();
    lote.update(db.collection('versiones_academicas').doc(v.id), {
      'nombre': v.nombre,
      'fechaApertura': Timestamp.fromDate(v.fechaApertura),
      'fechaCorte': v.fechaCorte == null
          ? null
          : Timestamp.fromDate(v.fechaCorte!),
      'estado': v.estado.name,
    });
    lote.set(
      _registro(),
      entradaRegistro(
        auth,
        tipo: 'version',
        descripcion: '${v.nombre}: $cambio',
      ),
    );
    await lote.commit();
  }

  @override
  Future<void> publicar(
    String versionId, {
    required List<String> temas,
    required int dia,
  }) async {
    final ya = await publicados(versionId);
    final todos = {...ya, ...temas}.toList()..sort();

    // Primero los documentos por tema (los usa el tutor en el servidor);
    // al final el resumen que lee la app y la entrada del registro.
    for (var i = 0; i < temas.length; i += _porLote) {
      final lote = db.batch();
      for (final t in temas.skip(i).take(_porLote)) {
        lote.set(db.collection('publicaciones_temas').doc('${versionId}__$t'), {
          'versionId': versionId,
          'temaId': t,
          'publicada': true,
        });
      }
      await lote.commit();
    }

    final lote = db.batch();
    lote.set(db.collection('publicaciones_version').doc(versionId), {
      'versionId': versionId,
      'temas': todos,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
    lote.set(
      _registro(),
      entradaRegistro(
        auth,
        tipo: 'publicacion',
        descripcion:
            'Publicó hasta el día $dia de $versionId (${temas.length} temas '
            'nuevos)',
      ),
    );
    await lote.commit();
  }

  @override
  Future<void> crear(
    VersionAcademica nueva, {
    required String origenId,
    required bool copiarMaterial,
    void Function(String mensaje)? progreso,
  }) async {
    final id = nueva.id;
    final (existe, curriculo) = await (
      db.collection('versiones_academicas').doc(id).get(),
      db.collection('curriculos').doc(origenId).get(),
    ).wait;
    if (existe.exists) {
      throw StateError('Ya existe una versión con el código $id.');
    }
    final temario = curriculo.data();
    if (temario == null) {
      throw StateError('La versión $origenId no tiene temario para copiar.');
    }

    if (copiarMaterial) {
      progreso?.call('Copiando videos, separatas y quizzes…');
      await _copiarMaterial(origenId, id, progreso);
    }

    // La versión se crea al final: si algo falla antes, no queda a medias.
    progreso?.call('Creando la versión…');
    final lote = db.batch();
    lote.set(db.collection('versiones_academicas').doc(id), {
      'codigo': nueva.codigo,
      'nombre': nueva.nombre,
      'fechaApertura': Timestamp.fromDate(nueva.fechaApertura),
      'fechaCorte': nueva.fechaCorte == null
          ? null
          : Timestamp.fromDate(nueva.fechaCorte!),
      'estado': EstadoVersionAcademica.preparacion.name,
      'copiadaDe': origenId,
      'creadaEn': FieldValue.serverTimestamp(),
    });
    lote.set(db.collection('planes_academicos').doc('${id}__plan'), {
      'versionId': id,
      'nombre': 'Plan ${nueva.nombre}',
      'activo': true,
    });
    lote.set(db.collection('curriculos').doc(id), {
      ...temario,
      'versionId': id,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
    lote.set(db.collection('publicaciones_version').doc(id), {
      'versionId': id,
      'temas': <String>[],
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
    lote.set(
      _registro(),
      entradaRegistro(
        auth,
        tipo: 'version',
        descripcion:
            'Creó ${nueva.nombre} copiando el temario de $origenId'
            '${copiarMaterial ? ' con su material' : ''} (abre el '
            '${fechaPanel(nueva.fechaApertura)})',
      ),
    );
    await lote.commit();
  }

  /// Copia recursos, evaluaciones, preguntas y claves con ids de la versión
  /// nueva. Las claves solo las puede leer el administrador.
  Future<void> _copiarMaterial(
    String origen,
    String destino,
    void Function(String mensaje)? progreso,
  ) async {
    Query<Map<String, dynamic>> conPrefijo(String coleccion) => db
        .collection(coleccion)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${origen}__')
        .where(FieldPath.documentId, isLessThan: '${origen}__');

    final (recursos, evaluaciones, preguntas, claves) = await (
      db.collection('recursos').where('versionId', isEqualTo: origen).get(),
      db.collection('evaluaciones').where('versionId', isEqualTo: origen).get(),
      conPrefijo('preguntas').get(),
      conPrefijo('claves_preguntas').get(),
    ).wait;

    final escrituras = <(String, String, Map<String, dynamic>)>[
      for (final d in recursos.docs)
        (
          'recursos',
          idEnVersion(d.id, origen, destino),
          {...d.data(), 'versionId': destino},
        ),
      for (final d in evaluaciones.docs)
        (
          'evaluaciones',
          idEnVersion(d.id, origen, destino),
          {...d.data(), 'versionId': destino},
        ),
      for (final d in preguntas.docs)
        (
          'preguntas',
          idEnVersion(d.id, origen, destino),
          {
            ...d.data(),
            'evaluacionId': idEnVersion(
              d.data()['evaluacionId'] as String? ?? '',
              origen,
              destino,
            ),
          },
        ),
      for (final d in claves.docs)
        ('claves_preguntas', idEnVersion(d.id, origen, destino), d.data()),
    ];

    for (var i = 0; i < escrituras.length; i += _porLote) {
      final lote = db.batch();
      for (final (coleccion, id, datos) in escrituras.skip(i).take(_porLote)) {
        lote.set(db.collection(coleccion).doc(id), datos);
      }
      await lote.commit();
      final hechos = (i + _porLote).clamp(0, escrituras.length);
      progreso?.call('Copiando material: $hechos de ${escrituras.length}…');
    }
  }
}
