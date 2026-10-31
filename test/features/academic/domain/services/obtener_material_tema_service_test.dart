import 'package:academiapp_v2/features/academic/domain/entities/contenido.dart';
import 'package:academiapp_v2/features/academic/domain/entities/recurso.dart';
import 'package:academiapp_v2/features/academic/domain/services/obtener_material_tema_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes_material.dart';

void main() {
  test('ordena contenidos por orden y recursos por tipo y titulo', () async {
    final service = ObtenerMaterialTemaService(
      repositorioContenido: RepositorioContenidoEnMemoria(const [
        Contenido(id: 'c2', temaId: 'geografia-01', nombre: 'B', orden: 2),
        Contenido(id: 'c1', temaId: 'geografia-01', nombre: 'A', orden: 1),
      ]),
      repositorioRecurso: RepositorioRecursoEnMemoria([
        recurso('r1', tipo: TipoRecurso.pdf, titulo: 'Separata'),
        recurso('r2', titulo: 'Clase 2'),
        recurso('r3', titulo: 'Clase 1'),
      ]),
    );

    final material = await service.obtener(
      temaId: 'geografia-01',
      versionId: 'version-1',
    );

    expect(material.contenidos.map((c) => c.id), ['c1', 'c2']);
    expect(material.recursos.map((r) => r.id), ['r3', 'r2', 'r1']);
  });

  test('solo muestra recursos de la version del estudiante', () async {
    final service = ObtenerMaterialTemaService(
      repositorioContenido: RepositorioContenidoEnMemoria(),
      repositorioRecurso: RepositorioRecursoEnMemoria([
        recurso('v1'),
        recurso('v2', versionId: 'version-2'),
      ]),
    );

    final material = await service.obtener(
      temaId: 'geografia-01',
      versionId: 'version-1',
    );

    expect(material.recursos.map((r) => r.id), ['v1']);
  });

  test('un recurso que reemplaza a otro oculta al anterior', () async {
    final service = ObtenerMaterialTemaService(
      repositorioContenido: RepositorioContenidoEnMemoria(),
      repositorioRecurso: RepositorioRecursoEnMemoria([
        recurso('clase-vieja', titulo: 'Clase'),
        recurso('clase-nueva', titulo: 'Clase', reemplazaA: 'clase-vieja'),
      ]),
    );

    final material = await service.obtener(
      temaId: 'geografia-01',
      versionId: 'version-1',
    );

    expect(material.recursos.map((r) => r.id), ['clase-nueva']);
  });

  test('tema sin material queda vacio', () async {
    final service = ObtenerMaterialTemaService(
      repositorioContenido: RepositorioContenidoEnMemoria(),
      repositorioRecurso: RepositorioRecursoEnMemoria(),
    );

    final material = await service.obtener(
      temaId: 'geografia-01',
      versionId: 'version-1',
    );

    expect(material.estaVacio, isTrue);
  });
}
