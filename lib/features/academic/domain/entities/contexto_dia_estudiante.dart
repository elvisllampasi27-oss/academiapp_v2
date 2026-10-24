import 'actividad_programada.dart';
import 'curso.dart';
import 'dia_academico.dart';
import 'plan_academico.dart';
import 'tema.dart';

class ContextoDiaEstudiante {
  final PlanAcademico plan;
  final DiaAcademico? dia;
  final List<ActividadProgramada> actividades;
  final List<Curso> cursos;
  final List<Tema> temas;

  const ContextoDiaEstudiante({
    required this.plan,
    required this.dia,
    required this.actividades,
    required this.cursos,
    required this.temas,
  });
}
