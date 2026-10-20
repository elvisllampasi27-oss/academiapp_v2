class ParametrosBkt {
  final double conocimientoInicial;
  final double aprendizaje;
  final double adivinanza;
  final double desliz;

  const ParametrosBkt({
    required this.conocimientoInicial,
    required this.aprendizaje,
    required this.adivinanza,
    required this.desliz,
  }) : assert(
         conocimientoInicial >= 0 && conocimientoInicial <= 1,
         'conocimientoInicial debe estar entre 0 y 1',
       ),
       assert(
         aprendizaje >= 0 && aprendizaje <= 1,
         'aprendizaje debe estar entre 0 y 1',
       ),
       assert(
         adivinanza >= 0 && adivinanza <= 1,
         'adivinanza debe estar entre 0 y 1',
       ),
       assert(desliz >= 0 && desliz <= 1, 'desliz debe estar entre 0 y 1');
}
