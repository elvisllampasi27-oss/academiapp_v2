import '../entities/publicacion_tema.dart';

abstract class RepositorioPublicacionTema {
  Future<List<PublicacionTema>> obtenerPublicadasPorVersionId(String versionId);
}
