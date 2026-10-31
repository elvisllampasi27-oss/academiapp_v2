/// Minúsculas y sin tildes, para búsquedas ("algebra" encuentra "Álgebra").
String normalizarTexto(String texto) {
  const conTilde = 'áéíóúüñ';
  const sinTilde = 'aeiouun';
  final buffer = StringBuffer();
  for (final caracter in texto.toLowerCase().split('')) {
    final i = conTilde.indexOf(caracter);
    buffer.write(i >= 0 ? sinTilde[i] : caracter);
  }
  return buffer.toString();
}

/// Siglas de un nombre para usar como ícono: "Razonamiento Verbal" -> "RV",
/// "Lenguaje" -> "Le".
String siglas(String nombre) {
  final palabras = nombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && p[0] == p[0].toUpperCase())
      .toList();
  if (palabras.length >= 2) {
    return '${palabras[0][0]}${palabras[1][0]}';
  }
  final unica = nombre.trim();
  if (unica.isEmpty) return '?';
  return unica.length == 1 ? unica : unica.substring(0, 2);
}
