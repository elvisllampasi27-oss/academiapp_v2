import 'seminario.dart';

/// El tema que más le cuesta al alumno dentro de un curso (según el BKT).
class TemaPorReforzar {
  final String tema;

  /// Dominio estimado, de 0 a 1.
  final double dominio;

  const TemaPorReforzar({required this.tema, required this.dominio});
}

/// Nombre de curso comparable: sin mayúsculas, tildes ni espacios de más
/// ("Matemática " y "matematica" son el mismo curso).
String claveCurso(String nombre) {
  const conTilde = 'áéíóúüñ';
  const sinTilde = 'aeiouun';
  final minusculas = nombre.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final letra in minusculas.split('')) {
    final i = conTilde.indexOf(letra);
    buffer.write(i == -1 ? letra : sinTilde[i]);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Con qué tema por reforzar ayuda [seminario], si es de un curso donde el
/// alumno tiene algo flojo. `null` si no tiene relación.
TemaPorReforzar? ayudaDelSeminario(
  Seminario seminario,
  Map<String, TemaPorReforzar> porCurso,
) {
  final curso = seminario.curso;
  if (curso == null || curso.trim().isEmpty) return null;
  return porCurso[claveCurso(curso)];
}
