import '../entities/curriculo.dart';

/// Temario y temas publicados de UNA versión académica.
abstract class RepositorioCurriculo {
  Future<Curriculo> obtener();

  Future<Set<String>> temasPublicados();
}
