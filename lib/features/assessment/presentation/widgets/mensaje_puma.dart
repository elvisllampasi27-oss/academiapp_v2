import '../../../../core/presentation/puma_tutor.dart';

/// Lo que dice el puma al terminar un quiz: un gesto y una frase según el
/// resultado. Cercano y con humor ligero, nunca burlón.
typedef MensajePuma = ({GestoPuma gesto, String texto});

MensajePuma mensajeDelPuma({
  required int correctas,
  required int total,
  required String tema,
  int? primeraFallada,
}) {
  if (total <= 0) {
    return (gesto: GestoPuma.atento, texto: 'Aquí tienes tu corrección.');
  }
  final falladas = total - correctas;
  final fraccion = correctas / total;
  final empieza = primeraFallada == null
      ? ''
      : ' Empieza por la pregunta $primeraFallada.';
  final lasQueFallaste = falladas == 1
      ? 'la que fallaste'
      : 'las $falladas que fallaste';

  if (falladas == 0) {
    return (
      gesto: GestoPuma.contento,
      texto: '¡Perfecto! $tema ya es territorio tuyo. Sigue así.',
    );
  }
  if (fraccion >= 0.7) {
    return (
      gesto: GestoPuma.contento,
      texto:
          '¡Muy bien! Casi lo tienes. Repasa $lasQueFallaste y '
          'quedas listo.$empieza',
    );
  }
  if (fraccion >= 0.4) {
    return (
      gesto: GestoPuma.atento,
      texto:
          'Vas por buen camino. Mira con calma $lasQueFallaste: ahí '
          'está lo que te falta.$empieza',
    );
  }
  return (
    gesto: GestoPuma.animo,
    texto:
        'Tranquilo, para eso es la práctica. Revisemos juntos '
        '$lasQueFallaste y vuelve a intentarlo.$empieza',
  );
}
