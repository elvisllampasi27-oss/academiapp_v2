import '../../features/academic/domain/entities/version_academica.dart';

/// Versiones académicas: datos, estado, publicación de temas y creación de
/// una versión nueva copiando otra. Cada cambio va al registro de acciones.
abstract class RepositorioVersionesAdmin {
  /// Temas publicados de la versión.
  Future<Set<String>> publicados(String versionId);

  /// Cambia nombre, fechas o estado. [cambio] describe qué se hizo.
  Future<void> guardar(VersionAcademica version, {required String cambio});

  /// Publica [temas] (los que faltan hasta el día [dia]).
  Future<void> publicar(
    String versionId, {
    required List<String> temas,
    required int dia,
  });

  /// Crea [nueva] copiando el temario de [origenId] y, si se pide, sus
  /// videos, separatas y quizzes. [progreso] recibe mensajes para mostrar.
  Future<void> crear(
    VersionAcademica nueva, {
    required String origenId,
    required bool copiarMaterial,
    void Function(String mensaje)? progreso,
  });
}
