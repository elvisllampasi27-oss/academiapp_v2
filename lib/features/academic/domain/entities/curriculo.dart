import 'area.dart';
import 'curso.dart';
import 'tema.dart';

/// Temario completo de una versión académica.
class Curriculo {
  final String versionId;
  final List<Area> areas;
  final List<Curso> cursos;
  final List<Tema> temas;

  const Curriculo({
    required this.versionId,
    required this.areas,
    required this.cursos,
    required this.temas,
  });

  List<Tema> temasDe(String cursoId) =>
      temas.where((t) => t.cursoId == cursoId).toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));

  Area? area(String id) {
    for (final area in areas) {
      if (area.id == id) return area;
    }
    return null;
  }
}
