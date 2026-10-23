import 'package:academiapp_v2/features/enrollment/domain/entities/matricula.dart';
import 'package:academiapp_v2/features/enrollment/domain/repositories/repositorio_matricula.dart';
import 'package:flutter_test/flutter_test.dart';

class RepositorioMatriculaFalso implements RepositorioMatricula {
  final List<Matricula> matriculas;

  RepositorioMatriculaFalso(this.matriculas);

  @override
  Future<Matricula?> buscarActivaPorUsuarioId(String usuarioId) async {
    for (final matricula in matriculas) {
      if (matricula.usuarioId == usuarioId &&
          matricula.estado == EstadoMatricula.activa) {
        return matricula;
      }
    }

    return null;
  }
}

void main() {
  test('encuentra la matricula activa del estudiante', () async {
    final matricula = Matricula(
      id: 'matricula-1',
      usuarioId: 'uid-123',
      versionId: 'version-1',
      fechaMatricula: DateTime(2026, 10, 20),
      fechaInicioAcademico: DateTime(2026, 10, 23),
      estado: EstadoMatricula.activa,
    );

    final repositorio = RepositorioMatriculaFalso([matricula]);

    final encontrada = await repositorio.buscarActivaPorUsuarioId('uid-123');

    expect(encontrada, isNotNull);
    expect(encontrada!.usuarioId, 'uid-123');
    expect(encontrada.versionId, 'version-1');
    expect(encontrada.estado, EstadoMatricula.activa);
  });

  test('devuelve null si el estudiante no tiene matricula activa', () async {
    final repositorio = RepositorioMatriculaFalso([]);

    final encontrada = await repositorio.buscarActivaPorUsuarioId('uid-123');

    expect(encontrada, isNull);
  });
}
