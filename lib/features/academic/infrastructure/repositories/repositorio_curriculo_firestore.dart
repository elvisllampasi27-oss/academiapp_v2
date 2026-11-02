import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/area.dart';
import '../../domain/entities/curriculo.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/publicacion_tema.dart';
import '../../domain/entities/tema.dart';
import '../../domain/repositories/repositorio_curriculo.dart';
import '../../domain/repositories/repositorio_curso.dart';
import '../../domain/repositories/repositorio_tema.dart';

/// Lee el temario de una versión desde 2 documentos resumen
/// (`curriculos/{version}` y `publicaciones_version/{version}`) y los
/// guarda en memoria: Inicio y Cursos comparten las mismas 2 lecturas
/// (antes eran ~220 lecturas por apertura del inicio).
class RepositorioCurriculoFirestore implements RepositorioCurriculo {
  final String versionId;
  final FirebaseFirestore firestore;

  Future<Curriculo>? _curriculo;
  Future<Set<String>>? _publicados;

  RepositorioCurriculoFirestore({
    required this.versionId,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  RepositorioCurso get cursos => _CursosDelCurriculo(this);

  @override
  RepositorioTema get temas => _TemasDelCurriculo(this);

  @override
  Future<Curriculo> obtener() => _curriculo ??= _leerCurriculo();

  @override
  Future<Set<String>> temasPublicados() => _publicados ??= _leerPublicados();

  @override
  Future<List<PublicacionTema>> obtenerPublicadasPorVersionId(
    String versionId,
  ) async {
    if (versionId != this.versionId) {
      throw ArgumentError(
        'Este repositorio es de la versión ${this.versionId}.',
      );
    }

    final publicados = await temasPublicados();

    return [
      for (final temaId in publicados)
        PublicacionTema(
          id: '${versionId}__$temaId',
          versionId: versionId,
          temaId: temaId,
          publicada: true,
        ),
    ];
  }

  Future<Curriculo> _leerCurriculo() async {
    final documento = await firestore
        .collection('curriculos')
        .doc(versionId)
        .get();
    final datos = documento.data();

    if (datos == null) {
      throw StateError(
        'El temario de la versión $versionId no está cargado. '
        'Ejecuta tool/seed_academico_v2.js con --apply.',
      );
    }

    return curriculoDesdeMapa(versionId, datos);
  }

  Future<Set<String>> _leerPublicados() async {
    final documento = await firestore
        .collection('publicaciones_version')
        .doc(versionId)
        .get();
    final temas = documento.data()?['temas'] as List? ?? const [];
    return temas.cast<String>().toSet();
  }
}

class _CursosDelCurriculo implements RepositorioCurso {
  final RepositorioCurriculo fuente;

  const _CursosDelCurriculo(this.fuente);

  @override
  Future<List<Curso>> obtenerActivos() async {
    final curriculo = await fuente.obtener();
    return curriculo.cursos.where((c) => c.activo).toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
  }
}

class _TemasDelCurriculo implements RepositorioTema {
  final RepositorioCurriculo fuente;

  const _TemasDelCurriculo(this.fuente);

  @override
  Future<List<Tema>> obtenerActivos() async {
    final curriculo = await fuente.obtener();
    return curriculo.temas.where((t) => t.activo).toList();
  }
}

/// Convierte el documento `curriculos/{version}` en entidades.
/// Función pura: se prueba sin Firebase.
Curriculo curriculoDesdeMapa(String versionId, Map<String, dynamic> datos) {
  List<Map<String, dynamic>> lista(String clave) =>
      (datos[clave] as List? ?? const []).cast<Map<String, dynamic>>();

  return Curriculo(
    versionId: versionId,
    areas: [
      for (final a in lista('areas'))
        Area(
          id: a['id'] as String,
          nombre: a['nombre'] as String,
          orden: (a['orden'] as num).toInt(),
        ),
    ]..sort((a, b) => a.orden.compareTo(b.orden)),
    cursos: [
      for (final c in lista('cursos'))
        Curso(
          id: c['id'] as String,
          areaId: c['areaId'] as String,
          nombre: c['nombre'] as String,
          orden: (c['orden'] as num).toInt(),
          icono: c['icono'] as String?,
        ),
    ],
    temas: [
      for (final t in lista('temas'))
        Tema(
          id: t['id'] as String,
          cursoId: t['cursoId'] as String,
          titulo: t['titulo'] as String,
          orden: (t['orden'] as num).toInt(),
          descripcion: t['descripcion'] as String?,
        ),
    ],
  );
}
