import '../entities/actividad_programada.dart';
import '../entities/contexto_dia_estudiante.dart';
import '../entities/dia_academico.dart';
import '../repositories/repositorio_curso.dart';
import '../repositories/repositorio_plan_academico.dart';
import '../repositories/repositorio_publicacion_tema.dart';
import '../repositories/repositorio_tema.dart';
import 'calendario_academico_service.dart';
import 'secuencia_academica_service.dart';

class ConstruirDiaEstudianteService {
  final RepositorioPlanAcademico repositorioPlan;
  final RepositorioCurso repositorioCurso;
  final RepositorioTema repositorioTema;
  final RepositorioPublicacionTema repositorioPublicacion;

  const ConstruirDiaEstudianteService({
    required this.repositorioPlan,
    required this.repositorioCurso,
    required this.repositorioTema,
    required this.repositorioPublicacion,
  });

  Future<ContextoDiaEstudiante?> construir({
    required String versionId,
    required DateTime fechaInicioAcademico,
    required DateTime fechaActual,
  }) async {
    final plan = await repositorioPlan.buscarActivoPorVersionId(versionId);

    if (plan == null) {
      return null;
    }

    final cursos = await repositorioCurso.obtenerActivos();
    final temas = await repositorioTema.obtenerActivos();

    final publicaciones = await repositorioPublicacion
        .obtenerPublicadasPorVersionId(versionId);

    final temasPublicados = publicaciones
        .where((publicacion) => publicacion.publicada)
        .map((publicacion) => publicacion.temaId)
        .toSet();

    final secuencia = const SecuenciaAcademicaService().generar(
      cursos: cursos,
      temas: temas,
    );

    final calendario = const CalendarioAcademicoService().generar(
      secuencia: secuencia,
      fechaInicio: fechaInicioAcademico,
    );

    final hoy = DateTime(fechaActual.year, fechaActual.month, fechaActual.day);

    DiaAcademico? diaActual;

    for (final dia in calendario) {
      if (dia.fecha == null) {
        continue;
      }

      final fechaDia = DateTime(
        dia.fecha!.year,
        dia.fecha!.month,
        dia.fecha!.day,
      );

      if (fechaDia == hoy) {
        diaActual = dia;
        break;
      }
    }

    final actividadesPublicadas = <ActividadProgramada>[];

    if (diaActual != null) {
      for (final actividad in diaActual.actividades) {
        if (temasPublicados.contains(actividad.temaId)) {
          actividadesPublicadas.add(
            ActividadProgramada(
              id: actividad.id,
              diaId: actividad.diaId,
              temaId: actividad.temaId,
              orden: actividad.orden,
              tipo: actividad.tipo,
              estado: EstadoActividadProgramada.publicada,
            ),
          );
        }
      }
    }

    return ContextoDiaEstudiante(
      plan: plan,
      dia: diaActual,
      actividades: actividadesPublicadas,
      cursos: cursos,
      temas: temas,
    );
  }
}
