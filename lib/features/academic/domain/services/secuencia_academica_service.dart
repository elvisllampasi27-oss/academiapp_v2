import '../entities/curso.dart';
import '../entities/tema.dart';

class SecuenciaAcademicaService {
  const SecuenciaAcademicaService();

  List<Tema> generar({required List<Curso> cursos, required List<Tema> temas}) {
    final cursosOrdenados = [...cursos]
      ..sort((a, b) => a.orden.compareTo(b.orden));

    final temasPorCurso = <String, List<Tema>>{};

    for (final curso in cursosOrdenados) {
      final temasDelCurso =
          temas
              .where((tema) => tema.cursoId == curso.id && tema.activo)
              .toList()
            ..sort((a, b) => a.orden.compareTo(b.orden));

      temasPorCurso[curso.id] = temasDelCurso;
    }

    final maximoTemas = temasPorCurso.values.fold<int>(
      0,
      (maximo, lista) => lista.length > maximo ? lista.length : maximo,
    );

    final secuencia = <Tema>[];

    for (var ronda = 0; ronda < maximoTemas; ronda++) {
      for (final curso in cursosOrdenados) {
        final temasDelCurso = temasPorCurso[curso.id]!;

        if (ronda < temasDelCurso.length) {
          secuencia.add(temasDelCurso[ronda]);
        }
      }
    }

    return secuencia;
  }
}
