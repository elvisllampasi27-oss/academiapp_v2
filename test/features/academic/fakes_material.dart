import 'package:academiapp_v2/features/academic/domain/entities/contenido.dart';
import 'package:academiapp_v2/features/academic/domain/entities/recurso.dart';
import 'package:academiapp_v2/features/academic/domain/repositories/repositorio_contenido.dart';
import 'package:academiapp_v2/features/academic/domain/repositories/repositorio_recurso.dart';

class RepositorioContenidoEnMemoria implements RepositorioContenido {
  final List<Contenido> contenidos;

  RepositorioContenidoEnMemoria([this.contenidos = const []]);

  @override
  Future<List<Contenido>> obtenerActivosPorTema(String temaId) async =>
      contenidos.where((c) => c.temaId == temaId && c.activo).toList();
}

class RepositorioRecursoEnMemoria implements RepositorioRecurso {
  final List<Recurso> recursos;
  bool fallar = false;

  RepositorioRecursoEnMemoria([this.recursos = const []]);

  @override
  Future<List<Recurso>> obtenerActivosPorTema({
    required String temaId,
    required String versionId,
  }) async {
    if (fallar) throw StateError('sin conexion');
    return recursos
        .where(
          (r) => r.temaId == temaId && r.versionId == versionId && r.activo,
        )
        .toList();
  }
}

Recurso recurso(
  String id, {
  TipoRecurso tipo = TipoRecurso.video,
  String titulo = 'Recurso',
  String temaId = 'geografia-01',
  String versionId = 'version-1',
  String ubicacion = 'https://ejemplo.pe/material',
  String? reemplazaA,
}) {
  return Recurso(
    id: id,
    temaId: temaId,
    versionId: versionId,
    tipo: tipo,
    titulo: titulo,
    ubicacion: ubicacion,
    reemplazaA: reemplazaA,
  );
}
