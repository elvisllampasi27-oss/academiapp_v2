import '../entities/contenido.dart';

abstract class RepositorioContenido {
  Future<List<Contenido>> obtenerActivosPorTema(String temaId);
}
