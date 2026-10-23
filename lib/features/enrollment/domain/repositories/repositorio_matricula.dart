import '../entities/matricula.dart';

abstract class RepositorioMatricula {
  Future<Matricula?> buscarActivaPorUsuarioId(String usuarioId);
}
