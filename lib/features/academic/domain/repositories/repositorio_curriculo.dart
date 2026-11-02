import '../entities/curriculo.dart';
import 'repositorio_curso.dart';
import 'repositorio_publicacion_tema.dart';
import 'repositorio_tema.dart';

/// Temario y temas publicados de UNA versión académica.
abstract class RepositorioCurriculo implements RepositorioPublicacionTema {
  Future<Curriculo> obtener();

  Future<Set<String>> temasPublicados();

  /// Vistas para `ConstruirDiaEstudianteService`, que pide cursos y temas
  /// por separado.
  RepositorioCurso get cursos;
  RepositorioTema get temas;
}
