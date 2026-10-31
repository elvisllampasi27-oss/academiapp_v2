import '../entities/evidencia.dart';

/// Evidencias de una matrícula y, para mostrarlas, a qué tema pertenece
/// cada habilidad.
class RegistroEvidencias {
  final List<Evidencia> evidencias;
  final Map<String, String> temaPorHabilidad;

  const RegistroEvidencias({
    required this.evidencias,
    required this.temaPorHabilidad,
  });
}

abstract class RepositorioEvidencia {
  Future<RegistroEvidencias> obtenerDeMatricula({
    required String usuarioId,
    required String matriculaId,
  });
}
