import 'actividad_programada.dart';
import 'curso.dart';
import 'dia_academico.dart';
import 'plan_academico.dart';
import 'semana_plan.dart';
import 'tema.dart';

class ContextoDiaEstudiante {
  final PlanAcademico plan;
  final DiaAcademico? dia;
  final List<ActividadProgramada> actividades;
  final List<Curso> cursos;
  final List<Tema> temas;

  /// La semana del plan de hoy (barra semanal). null si aún no empieza.
  final SemanaPlan? semana;

  const ContextoDiaEstudiante({
    required this.plan,
    required this.dia,
    required this.actividades,
    required this.cursos,
    required this.temas,
    this.semana,
  });
}
