import '../entities/curso.dart';

abstract class RepositorioCurso {
  Future<List<Curso>> obtenerActivos();
}
