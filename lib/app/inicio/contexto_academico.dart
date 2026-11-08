import '../../features/academic/domain/entities/contexto_dia_estudiante.dart';
import '../../features/academic/domain/entities/curriculo.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../../features/academic/domain/repositories/repositorio_curriculo.dart';
import '../../features/academic/domain/repositories/repositorio_plan_academico.dart';
import '../../features/academic/domain/repositories/repositorio_version_academica.dart';
import '../../features/academic/domain/services/construir_dia_estudiante_service.dart';
import '../../features/adaptive_engine/domain/entities/item_mi_ruta.dart';
import '../../features/adaptive_engine/domain/services/construir_mi_ruta_service.dart';
import '../../features/enrollment/domain/entities/matricula.dart';
import '../../features/enrollment/domain/repositories/repositorio_matricula.dart';

/// Todo lo que el estudiante necesita al abrir la app: su matrícula, el día
/// académico, su ruta y el temario de su versión.
class ContextoAcademico {
  final Matricula matricula;
  final VersionAcademica versionAcademica;
  final ContextoDiaEstudiante diaEstudiante;
  final List<ItemMiRuta> ruta;
  final Curriculo curriculo;
  final Set<String> publicados;

  /// Cuándo respondió preguntas el alumno (de sus evidencias): su actividad.
  final List<DateTime> actividad;

  const ContextoAcademico({
    required this.matricula,
    required this.versionAcademica,
    required this.diaEstudiante,
    required this.ruta,
    required this.curriculo,
    required this.publicados,
    this.actividad = const [],
  });
}

/// Caso de uso: arma el [ContextoAcademico] de un estudiante.
/// Devuelve null si no tiene matrícula activa.
class CargarContextoAcademicoService {
  final RepositorioMatricula matriculas;
  final RepositorioVersionAcademica versiones;
  final RepositorioPlanAcademico planes;
  final RepositorioCurriculo Function(String versionId) curriculoDe;
  final ConstruirMiRutaService ruta;

  const CargarContextoAcademicoService({
    required this.matriculas,
    required this.versiones,
    required this.planes,
    required this.curriculoDe,
    required this.ruta,
  });

  Future<ContextoAcademico?> cargar({
    required String usuarioId,
    required DateTime ahora,
  }) async {
    final matricula = await matriculas.buscarActivaPorUsuarioId(usuarioId);
    if (matricula == null) return null;

    final version = await versiones.buscarPorId(matricula.versionId);
    if (version == null) {
      throw StateError(
        'La versión académica ${matricula.versionId} no existe.',
      );
    }

    // Temario y publicaciones de la versión: 2 lecturas, compartidas por
    // el inicio y la pestaña Cursos.
    final curriculo = curriculoDe(matricula.versionId);

    final dia =
        await ConstruirDiaEstudianteService(
          repositorioPlan: planes,
          repositorioCurso: curriculo.cursos,
          repositorioTema: curriculo.temas,
          repositorioPublicacion: curriculo,
        ).construir(
          versionId: matricula.versionId,
          fechaInicioAcademico: matricula.fechaInicioAcademico,
          fechaActual: ahora,
        );

    if (dia == null) {
      throw StateError(
        'No existe un plan académico activo para ${matricula.versionId}.',
      );
    }

    final (:items, :actividad) = await _ruta(usuarioId, matricula.id);
    return ContextoAcademico(
      matricula: matricula,
      versionAcademica: version,
      diaEstudiante: dia,
      ruta: items,
      curriculo: await curriculo.obtener(),
      publicados: await curriculo.temasPublicados(),
      actividad: actividad,
    );
  }

  /// La ruta (y la actividad) son un complemento: si fallan, el inicio
  /// igual se muestra.
  Future<({List<ItemMiRuta> items, List<DateTime> actividad})> _ruta(
    String usuarioId,
    String matriculaId,
  ) async {
    try {
      return await ruta.construirConActividad(
        usuarioId: usuarioId,
        matriculaId: matriculaId,
      );
    } catch (_) {
      return (items: const <ItemMiRuta>[], actividad: const <DateTime>[]);
    }
  }
}
