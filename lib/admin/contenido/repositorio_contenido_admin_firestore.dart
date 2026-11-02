import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/academic/domain/entities/tema.dart';
import '../../features/academic/infrastructure/repositories/repositorio_curriculo_firestore.dart';
import '../registro_admin.dart';
import 'modelo_contenido.dart';
import 'repositorio_contenido_admin.dart';

class RepositorioContenidoAdminFirestore implements RepositorioContenidoAdmin {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  RepositorioContenidoAdminFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  String _idRecurso(String v, String tema, String tipo) =>
      '${v}__${tema}__$tipo-1';

  @override
  Future<ResumenContenido> resumen(String versionId) async {
    // ~5 consultas por versión: temario, publicados, recursos, contenidos,
    // evaluaciones y preguntas (solo para contarlas).
    final (
      curriculo,
      publicados,
      recursos,
      contenidos,
      evaluaciones,
      preguntas,
    ) = await (
      db.collection('curriculos').doc(versionId).get(),
      db.collection('publicaciones_version').doc(versionId).get(),
      db.collection('recursos').where('versionId', isEqualTo: versionId).get(),
      db.collection('contenidos').where('activo', isEqualTo: true).get(),
      db
          .collection('evaluaciones')
          .where('versionId', isEqualTo: versionId)
          .get(),
      db
          .collection('preguntas')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${versionId}__')
          .where(FieldPath.documentId, isLessThan: '${versionId}__')
          .get(),
    ).wait;

    final datos = curriculo.data();
    if (datos == null) {
      throw StateError('La versión $versionId no tiene temario.');
    }

    final video = <String, String>{};
    final separata = <String, String>{};
    for (final d in recursos.docs) {
      final r = d.data();
      if (r['activo'] == false) continue;
      final tema = r['temaId'] as String?;
      final ubicacion = r['ubicacion'] as String?;
      if (tema == null || ubicacion == null || ubicacion.isEmpty) continue;
      if (r['tipo'] == 'video') video.putIfAbsent(tema, () => ubicacion);
      if (r['tipo'] == 'pdf') separata.putIfAbsent(tema, () => ubicacion);
    }

    final porTema = <String, List<(int, String)>>{};
    for (final d in contenidos.docs) {
      final c = d.data();
      final tema = c['temaId'] as String?;
      if (tema == null) continue;
      porTema.putIfAbsent(tema, () => []).add((
        (c['orden'] as num?)?.toInt() ?? 0,
        (c['nombre'] as String?) ?? '',
      ));
    }

    final cuenta = <String, int>{};
    for (final d in preguntas.docs) {
      if (d.data()['activa'] == false) continue;
      final e = d.data()['evaluacionId'] as String?;
      if (e != null) cuenta[e] = (cuenta[e] ?? 0) + 1;
    }
    final quizzes = <String, Map<NivelQuiz, QuizTema>>{};
    for (final d in evaluaciones.docs) {
      final e = d.data();
      final nivel = NivelQuiz.values.asNameMap()[e['nivel']];
      final tema = e['temaId'] as String?;
      if (nivel == null || tema == null) continue;
      quizzes.putIfAbsent(tema, () => {})[nivel] = QuizTema(
        nivel,
        publicado: e['estado'] == 'publicada',
        preguntas: cuenta[d.id] ?? 0,
      );
    }

    final temario = curriculoDesdeMapa(versionId, datos);
    return ResumenContenido(
      curriculo: temario,
      publicados: ((publicados.data()?['temas'] as List?) ?? const [])
          .cast<String>()
          .toSet(),
      material: {
        for (final t in temario.temas)
          t.id: MaterialTema(
            temaId: t.id,
            video: video[t.id],
            separata: separata[t.id],
            contenidos: [
              for (final (_, nombre)
                  in (porTema[t.id] ?? [])
                    ..sort((a, b) => a.$1.compareTo(b.$1)))
                nombre,
            ],
            quizzes: quizzes[t.id] ?? const {},
          ),
      },
    );
  }

  @override
  Future<String> materialTutor(String versionId, String temaId) async {
    final d = await db
        .collection('material_tutor')
        .doc('${versionId}__$temaId')
        .get();
    return (d.data()?['texto'] as String?) ?? '';
  }

  @override
  Future<List<PreguntaPractica>> preguntas(
    String versionId,
    String temaId,
    NivelQuiz nivel,
  ) async {
    final evaluacionId = idEvaluacion(versionId, temaId, nivel);
    final q = await db
        .collection('preguntas')
        .where('evaluacionId', isEqualTo: evaluacionId)
        .get();
    final docs = q.docs.where((d) => d.data()['activa'] != false).toList()
      ..sort(
        (a, b) => ((a.data()['orden'] as num?) ?? 0).compareTo(
          (b.data()['orden'] as num?) ?? 0,
        ),
      );
    final claves = await Future.wait([
      for (final d in docs) db.collection('claves_preguntas').doc(d.id).get(),
    ]);
    return [
      for (final (i, d) in docs.indexed)
        () {
          final opciones = ((d.data()['opciones'] as List?) ?? const [])
              .cast<Map<String, dynamic>>();
          final clave = claves[i].data() ?? const {};
          return PreguntaPractica(
            enunciado: (d.data()['enunciado'] as String?) ?? '',
            opciones: [for (final o in opciones) (o['texto'] as String?) ?? ''],
            correcta: opciones.indexWhere(
              (o) => o['id'] == clave['opcionCorrectaId'],
            ),
            explicacion: (clave['explicacion'] as String?) ?? '',
          );
        }(),
    ];
  }

  @override
  Future<void> guardarTema({
    required String versionId,
    required Tema tema,
    required String titulo,
    required String? video,
    required String? separata,
    required List<String> contenidos,
    required String materialTutor,
  }) async {
    // El título vive en el temario de la versión (un documento).
    if (titulo != tema.titulo) {
      await db.runTransaction((tx) async {
        final ref = db.collection('curriculos').doc(versionId);
        final datos = (await tx.get(ref)).data();
        if (datos == null) throw StateError('La versión no tiene temario.');
        final temas = [
          for (final t in (datos['temas'] as List).cast<Map<String, dynamic>>())
            t['id'] == tema.id ? {...t, 'titulo': titulo} : t,
        ];
        tx.update(ref, {
          'temas': temas,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      });
    }

    final lote = db.batch();
    void recurso(String tipo, String? ubicacion, String nombre) {
      final ref = db
          .collection('recursos')
          .doc(_idRecurso(versionId, tema.id, tipo));
      // Sin enlace queda inactivo (la app solo lee los activos).
      lote.set(ref, {
        'temaId': tema.id,
        'versionId': versionId,
        'tipo': tipo,
        'titulo': '$nombre · $titulo',
        'ubicacion': ubicacion ?? '',
        'activo': ubicacion != null,
        'reemplazaA': null,
      });
    }

    recurso('video', video, 'Clase');
    recurso('pdf', separata, 'Separata');

    // Contenidos: compartidos por todas las versiones (por tema).
    final anteriores = await db
        .collection('contenidos')
        .where('temaId', isEqualTo: tema.id)
        .get();
    for (final d in anteriores.docs) {
      lote.update(d.reference, {'activo': false});
    }
    for (final (i, nombre) in contenidos.indexed) {
      final orden = i + 1;
      lote.set(
        db
            .collection('contenidos')
            .doc('${tema.id}-c${orden.toString().padLeft(2, '0')}'),
        {
          'temaId': tema.id,
          'nombre': nombre,
          'descripcion': null,
          'orden': orden,
          'activo': true,
        },
      );
    }

    lote.set(db.collection('material_tutor').doc('${versionId}__${tema.id}'), {
      'versionId': versionId,
      'temaId': tema.id,
      'texto': materialTutor,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
    lote.set(
      db.collection('registro_admin').doc(),
      entradaRegistro(
        auth,
        tipo: 'contenido',
        descripcion: 'Editó el material de "$titulo" ($versionId)',
      ),
    );
    await lote.commit();
  }

  @override
  Future<void> guardarQuiz({
    required String versionId,
    required Tema tema,
    required NivelQuiz nivel,
    required List<PreguntaPractica> preguntas,
    required bool publicar,
  }) async {
    final evaluacionId = idEvaluacion(versionId, tema.id, nivel);
    final previas = await db
        .collection('preguntas')
        .where('evaluacionId', isEqualTo: evaluacionId)
        .get();
    final nuevas = {
      for (var i = 0; i < preguntas.length; i++)
        idPregunta(evaluacionId, i + 1),
    };

    final lote = db.batch();
    lote.set(db.collection('evaluaciones').doc(evaluacionId), {
      'temaId': tema.id,
      'versionId': versionId,
      'tipo': 'practica',
      'nivel': nivel.name,
      'estado': publicar ? 'publicada' : 'borrador',
    });
    for (final (i, p) in preguntas.indexed) {
      final id = idPregunta(evaluacionId, i + 1);
      lote.set(db.collection('preguntas').doc(id), {
        'evaluacionId': evaluacionId,
        'enunciado': p.enunciado.trim(),
        'dificultad': nivel.name,
        'orden': i + 1,
        'activa': true,
        'opciones': [
          for (final (k, o) in p.opciones.indexed)
            {'id': PreguntaPractica.letras[k], 'texto': o.trim()},
        ],
        'habilidades': const <String>[],
      });
      lote.set(db.collection('claves_preguntas').doc(id), {
        'opcionCorrectaId': PreguntaPractica.letras[p.correcta],
        'explicacion': p.explicacion.trim().isEmpty
            ? null
            : p.explicacion.trim(),
      });
    }
    // Las que sobran se desactivan (las respuestas viejas siguen valiendo).
    for (final d in previas.docs) {
      if (!nuevas.contains(d.id)) lote.update(d.reference, {'activa': false});
    }
    lote.set(
      db.collection('registro_admin').doc(),
      entradaRegistro(
        auth,
        tipo: 'quiz',
        descripcion:
            '${publicar ? 'Publicó' : 'Guardó como borrador'} el quiz '
            '${nivel.etiqueta.toLowerCase()} de "${tema.titulo}" '
            '(${preguntas.length} preguntas)',
      ),
    );
    await lote.commit();
  }

  @override
  Future<void> cambiarPublicacion({
    required String versionId,
    required Tema tema,
    required bool publicar,
  }) async {
    final lote = db.batch();
    lote.set(
      db.collection('publicaciones_temas').doc('${versionId}__${tema.id}'),
      {'versionId': versionId, 'temaId': tema.id, 'publicada': publicar},
    );
    lote.set(db.collection('publicaciones_version').doc(versionId), {
      'versionId': versionId,
      'temas': publicar
          ? FieldValue.arrayUnion([tema.id])
          : FieldValue.arrayRemove([tema.id]),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    lote.set(
      db.collection('registro_admin').doc(),
      entradaRegistro(
        auth,
        tipo: 'publicacion',
        descripcion:
            '${publicar ? 'Publicó' : 'Ocultó'} "${tema.titulo}" ($versionId)',
      ),
    );
    await lote.commit();
  }
}

/// Llama a la función generarPreguntas (Gemini) del servidor.
class GeneradorQuizFunctions implements GeneradorQuiz {
  final FirebaseFunctions functions;

  GeneradorQuizFunctions({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<List<PreguntaPractica>> generar({
    required String versionId,
    required String temaId,
    required NivelQuiz nivel,
    required int cantidad,
  }) async {
    try {
      final r = await functions
          .httpsCallable(
            'generarPreguntas',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call<Map<Object?, Object?>>({
            'versionId': versionId,
            'temaId': temaId,
            'nivel': nivel.name,
            'cantidad': cantidad,
          });
      final lista = (r.data['preguntas'] as List?) ?? const [];
      return [
        for (final p in lista.cast<Map<Object?, Object?>>())
          PreguntaPractica(
            enunciado: (p['enunciado'] as String?) ?? '',
            opciones: ((p['opciones'] as List?) ?? const []).cast<String>(),
            correcta: (p['correcta'] as num?)?.toInt() ?? -1,
            explicacion: (p['explicacion'] as String?) ?? '',
          ),
      ];
    } on FirebaseFunctionsException catch (e) {
      throw StateError(e.message ?? 'No se pudo generar el quiz.');
    }
  }
}
