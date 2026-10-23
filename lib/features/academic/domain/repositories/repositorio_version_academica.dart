import '../entities/version_academica.dart';

abstract class RepositorioVersionAcademica {
  Future<VersionAcademica?> buscarPorId(String versionId);
}
