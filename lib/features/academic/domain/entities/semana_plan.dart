/// La semana del plan en la que está el alumno: sus temas y el día de su
/// examen semanal (el sábado).
class SemanaPlan {
  /// 1, 2, 3… (la misma numeración que el examen semanal).
  final int numero;

  /// Temas publicados de la semana (de lunes a sábado), en orden.
  final List<String> temaIds;

  /// El sábado de la semana: ese día se abre su examen.
  final DateTime sabado;

  const SemanaPlan({
    required this.numero,
    required this.temaIds,
    required this.sabado,
  });
}
