import 'package:academiapp_v2/app/inicio/contexto_academico.dart';
import 'package:academiapp_v2/features/academic/domain/entities/area.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curriculo.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/plan_academico.dart';
import 'package:academiapp_v2/features/academic/domain/entities/publicacion_tema.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/entities/version_academica.dart';
import 'package:academiapp_v2/features/academic/domain/repositories/repositorio_curriculo.dart';
import 'package:academiapp_v2/features/academic/domain/repositories/repositorio_curso.dart';
import 'package:academiapp_v2/features/academic/domain/repositories/repositorio_plan_academico.dart';
import 'package:academiapp_v2/features/academic/domain/repositories/repositorio_tema.dart';
import 'package:academiapp_v2/features/academic/domain/repositories/repositorio_version_academica.dart';
import 'package:academiapp_v2/features/adaptive_engine/domain/services/construir_mi_ruta_service.dart';
import 'package:academiapp_v2/features/enrollment/domain/entities/matricula.dart';
import 'package:academiapp_v2/features/enrollment/domain/repositories/repositorio_matricula.dart';
import 'package:academiapp_v2/features/student_model/domain/repositories/repositorio_evidencia.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/adaptive_engine/fakes_mi_ruta.dart';

class _Matriculas implements RepositorioMatricula {
  final Matricula? matricula;
  _Matriculas(this.matricula);
  @override
  Future<Matricula?> buscarActivaPorUsuarioId(String usuarioId) async =>
      matricula;
}

class _Versiones implements RepositorioVersionAcademica {
  final VersionAcademica? version;
  _Versiones(this.version);
  @override
  Future<VersionAcademica?> buscarPorId(String versionId) async => version;
}

class _Planes implements RepositorioPlanAcademico {
  @override
  Future<PlanAcademico?> buscarActivoPorVersionId(String versionId) async =>
      PlanAcademico(id: 'plan-1', versionId: versionId, nombre: 'Plan');
}

class _Curriculo implements RepositorioCurriculo {
  final Curriculo curriculo;
  final Set<String> publicados;
  _Curriculo(this.curriculo, this.publicados);

  @override
  Future<Curriculo> obtener() async => curriculo;

  @override
  Future<Set<String>> temasPublicados() async => publicados;

  @override
  Future<List<PublicacionTema>> obtenerPublicadasPorVersionId(
    String versionId,
  ) async => [
    for (final t in publicados)
      PublicacionTema(
        id: '${versionId}__$t',
        versionId: versionId,
        temaId: t,
        publicada: true,
      ),
  ];

  @override
  RepositorioCurso get cursos => _Cursos(curriculo.cursos);

  @override
  RepositorioTema get temas => _Temas(curriculo.temas);
}

class _Cursos implements RepositorioCurso {
  final List<Curso> lista;
  _Cursos(this.lista);
  @override
  Future<List<Curso>> obtenerActivos() async => lista;
}

class _Temas implements RepositorioTema {
  final List<Tema> lista;
  _Temas(this.lista);
  @override
  Future<List<Tema>> obtenerActivos() async => lista;
}

class _EvidenciasRotas implements RepositorioEvidencia {
  @override
  Future<RegistroEvidencias> obtenerDeMatricula({
    required String usuarioId,
    required String matriculaId,
  }) => throw StateError('sin conexión');
}

void main() {
  final inicio = DateTime(2026, 10, 26); // lunes
  final matricula = Matricula(
    id: 'm1',
    usuarioId: 'u1',
    versionId: 'version-1',
    fechaMatricula: inicio,
    fechaInicioAcademico: inicio,
    estado: EstadoMatricula.activa,
  );
  final version = VersionAcademica(
    id: 'version-1',
    codigo: '2026-II',
    nombre: 'Ciclo 2026-II',
    fechaApertura: inicio,
    estado: EstadoVersionAcademica.activa,
  );
  final curriculo = Curriculo(
    versionId: 'version-1',
    areas: const [Area(id: 'matematica', nombre: 'Matemática', orden: 1)],
    cursos: const [
      Curso(
        id: 'aritmetica',
        areaId: 'matematica',
        nombre: 'Aritmética',
        orden: 1,
      ),
      Curso(id: 'algebra', areaId: 'matematica', nombre: 'Álgebra', orden: 2),
      Curso(
        id: 'geometria',
        areaId: 'matematica',
        nombre: 'Geometría',
        orden: 3,
      ),
    ],
    temas: const [
      Tema(id: 'aritmetica-01', cursoId: 'aritmetica', titulo: 'A1', orden: 1),
      Tema(id: 'algebra-01', cursoId: 'algebra', titulo: 'B1', orden: 1),
      Tema(id: 'geometria-01', cursoId: 'geometria', titulo: 'G1', orden: 1),
    ],
  );

  CargarContextoAcademicoService servicio({
    Matricula? conMatricula,
    VersionAcademica? conVersion,
    RepositorioEvidencia? evidencias,
  }) {
    return CargarContextoAcademicoService(
      matriculas: _Matriculas(conMatricula),
      versiones: _Versiones(conVersion),
      planes: _Planes(),
      curriculoDe: (_) =>
          _Curriculo(curriculo, {'aritmetica-01', 'algebra-01'}),
      ruta: ConstruirMiRutaService(
        repositorio: evidencias ?? RepositorioEvidenciaEnMemoria(const []),
      ),
    );
  }

  test('sin matricula activa no hay contexto', () async {
    final contexto = await servicio().cargar(usuarioId: 'u1', ahora: inicio);
    expect(contexto, isNull);
  });

  test('arma el dia con solo los temas publicados', () async {
    final contexto = await servicio(
      conMatricula: matricula,
      conVersion: version,
    ).cargar(usuarioId: 'u1', ahora: inicio);

    expect(contexto!.versionAcademica.nombre, 'Ciclo 2026-II');
    expect(contexto.publicados, {'aritmetica-01', 'algebra-01'});
    expect(contexto.diaEstudiante.actividades.map((a) => a.temaId).toSet(), {
      'aritmetica-01',
      'algebra-01',
    });
    expect(contexto.curriculo.cursos, hasLength(3));
  });

  test('si falla la ruta igual se muestra el inicio', () async {
    final contexto = await servicio(
      conMatricula: matricula,
      conVersion: version,
      evidencias: _EvidenciasRotas(),
    ).cargar(usuarioId: 'u1', ahora: inicio);

    expect(contexto, isNotNull);
    expect(contexto!.ruta, isEmpty);
  });

  test('una version inexistente es un error claro', () async {
    expect(
      servicio(conMatricula: matricula).cargar(usuarioId: 'u1', ahora: inicio),
      throwsA(isA<StateError>()),
    );
  });
}
