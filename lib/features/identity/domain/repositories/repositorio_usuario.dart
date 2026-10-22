import '../entities/usuario_academiapp.dart';

abstract class RepositorioUsuario {
  Future<void> guardar(UsuarioAcademiApp usuario);

  Future<UsuarioAcademiApp?> buscarPorUid(String uid);
}
