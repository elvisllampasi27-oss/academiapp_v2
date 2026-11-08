import '../../features/academic/domain/entities/curriculo.dart';
import '../../features/adaptive_engine/domain/entities/item_mi_ruta.dart';
import '../../features/adaptive_engine/domain/entities/recomendacion.dart';
import '../../features/seminars/domain/relevancia_seminario.dart';

/// Por cada curso (con su nombre normalizado, ver [claveCurso]), el tema que
/// el BKT recomienda reforzar con el dominio más bajo. Sirve para destacar
/// los seminarios que le ayudan al alumno.
Map<String, TemaPorReforzar> temasPorReforzarPorCurso(
  List<ItemMiRuta> ruta,
  Curriculo curriculo,
) {
  final temas = {for (final t in curriculo.temas) t.id: t};
  final cursos = {for (final c in curriculo.cursos) c.id: c};
  final resultado = <String, TemaPorReforzar>{};

  for (final item in ruta) {
    if (item.recomendacion.tipo != TipoRecomendacion.reforzar) continue;
    final tema = temas[item.temaId];
    final curso = tema == null ? null : cursos[tema.cursoId];
    if (tema == null || curso == null) continue;

    final clave = claveCurso(curso.nombre);
    final actual = resultado[clave];
    if (actual == null || item.estado.valor < actual.dominio) {
      resultado[clave] = TemaPorReforzar(
        tema: tema.titulo,
        dominio: item.estado.valor,
      );
    }
  }
  return resultado;
}
