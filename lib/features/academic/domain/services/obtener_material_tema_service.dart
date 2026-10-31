import '../entities/contenido.dart';
import '../entities/material_tema.dart';
import '../entities/recurso.dart';
import '../repositories/repositorio_contenido.dart';
import '../repositories/repositorio_recurso.dart';

class ObtenerMaterialTemaService {
  final RepositorioContenido repositorioContenido;
  final RepositorioRecurso repositorioRecurso;

  const ObtenerMaterialTemaService({
    required this.repositorioContenido,
    required this.repositorioRecurso,
  });

  Future<MaterialTema> obtener({
    required String temaId,
    required String versionId,
  }) async {
    late List<Contenido> contenidosCargados;
    late List<Recurso> recursosCargados;

    // Future.wait escucha ambas consultas desde el inicio: si una falla,
    // el error se propaga una sola vez y ninguno queda sin capturar.
    await Future.wait([
      repositorioContenido
          .obtenerActivosPorTema(temaId)
          .then((lista) => contenidosCargados = lista),
      repositorioRecurso
          .obtenerActivosPorTema(temaId: temaId, versionId: versionId)
          .then((lista) => recursosCargados = lista),
    ]);

    final contenidos = [...contenidosCargados]
      ..sort((a, b) => a.orden.compareTo(b.orden));

    final recursos = _vigentes(recursosCargados)
      ..sort((a, b) {
        final porTipo = a.tipo.index.compareTo(b.tipo.index);
        return porTipo != 0 ? porTipo : a.titulo.compareTo(b.titulo);
      });

    return MaterialTema(contenidos: contenidos, recursos: recursos);
  }

  /// Si un recurso declara `reemplazaA`, el recurso reemplazado deja de
  /// mostrarse (p. ej. un video regrabado sustituye al anterior).
  List<Recurso> _vigentes(List<Recurso> recursos) {
    final reemplazados = recursos
        .map((r) => r.reemplazaA)
        .whereType<String>()
        .toSet();

    return recursos.where((r) => !reemplazados.contains(r.id)).toList();
  }
}
