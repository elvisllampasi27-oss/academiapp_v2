import 'package:academiapp_v2/features/academic/domain/entities/version_academica.dart';
import 'package:academiapp_v2/features/academic/domain/repositories/repositorio_version_academica.dart';
import 'package:flutter_test/flutter_test.dart';

class RepositorioVersionAcademicaFalso implements RepositorioVersionAcademica {
  final List<VersionAcademica> versiones;

  RepositorioVersionAcademicaFalso(this.versiones);

  @override
  Future<VersionAcademica?> buscarPorId(String versionId) async {
    for (final version in versiones) {
      if (version.id == versionId) {
        return version;
      }
    }

    return null;
  }
}

void main() {
  test('encuentra una version academica por su id', () async {
    final version = VersionAcademica(
      id: 'version-1',
      codigo: 'V1',
      nombre: 'AcademiApp V1',
      fechaApertura: DateTime(2026, 10, 23),
      estado: EstadoVersionAcademica.activa,
    );

    final repositorio = RepositorioVersionAcademicaFalso([version]);

    final encontrada = await repositorio.buscarPorId('version-1');

    expect(encontrada, isNotNull);
    expect(encontrada!.id, 'version-1');
    expect(encontrada.codigo, 'V1');
    expect(encontrada.estado, EstadoVersionAcademica.activa);
  });

  test('devuelve null cuando la version no existe', () async {
    final repositorio = RepositorioVersionAcademicaFalso([]);

    final encontrada = await repositorio.buscarPorId('version-1');

    expect(encontrada, isNull);
  });
}
