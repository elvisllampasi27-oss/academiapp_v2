import '../entities/tema.dart';

abstract class RepositorioTema {
  Future<List<Tema>> obtenerActivos();
}
