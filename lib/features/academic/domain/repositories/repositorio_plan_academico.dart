import '../entities/plan_academico.dart';

abstract class RepositorioPlanAcademico {
  Future<PlanAcademico?> buscarActivoPorVersionId(String versionId);
}
