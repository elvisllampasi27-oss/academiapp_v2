/// Pregunta que aparece dentro de la clase, en un segundo del video. Es
/// para que el alumno se detenga a pensar: no tiene nota ni se guarda.
class PreguntaVideo {
  final String id;

  /// Segundo del video en que aparece.
  final int segundo;
  final String enunciado;
  final List<OpcionVideo> opciones;
  final String correctaId;

  /// Por qué es la correcta (se muestra después de responder).
  final String? explicacion;

  const PreguntaVideo({
    required this.id,
    required this.segundo,
    required this.enunciado,
    required this.opciones,
    required this.correctaId,
    this.explicacion,
  });

  OpcionVideo? get correcta {
    for (final o in opciones) {
      if (o.id == correctaId) return o;
    }
    return null;
  }
}

class OpcionVideo {
  final String id;
  final String texto;

  const OpcionVideo({required this.id, required this.texto});
}

/// La pregunta que toca al pasar el video de [anterior] a [actual]
/// segundos. Solo en la reproducción normal: si adelanta o retrocede de un
/// salto, no interrumpe. Cada pregunta sale una vez por visita.
PreguntaVideo? preguntaQueToca(
  List<PreguntaVideo> preguntas, {
  required double anterior,
  required double actual,
  required Set<String> respondidas,
}) {
  if (actual <= anterior || actual - anterior > 3) return null;
  for (final p in preguntas) {
    if (!respondidas.contains(p.id) &&
        p.segundo > anterior &&
        p.segundo <= actual) {
      return p;
    }
  }
  return null;
}

/// "1:30" → 90, "90" → 90, "1:02:03" → 3723. null si no se entiende.
int? segundosDesdeTexto(String texto) {
  final partes = texto.trim().split(':');
  if (partes.isEmpty || partes.length > 3) return null;
  var total = 0;
  for (final (i, parte) in partes.indexed) {
    final n = int.tryParse(parte);
    if (n == null || n < 0 || (i > 0 && n > 59)) return null;
    total = total * 60 + n;
  }
  return total;
}

/// 90 → "1:30"; 3723 → "1:02:03".
String textoDeSegundos(int segundos) {
  final h = segundos ~/ 3600;
  final m = (segundos % 3600) ~/ 60;
  final s = (segundos % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Documento `preguntas_video/{versionId}__{temaId}`: { preguntas: [...] }.
List<PreguntaVideo> preguntasVideoDesdeMapa(Map<String, dynamic>? datos) {
  final lista = datos?['preguntas'];
  if (lista is! List) return const [];
  final preguntas = <PreguntaVideo>[];
  for (final (i, p) in lista.indexed) {
    if (p is! Map) continue;
    final opciones = [
      if (p['opciones'] case final List ops)
        for (final o in ops)
          if (o is Map && o['id'] is String && o['texto'] is String)
            OpcionVideo(id: o['id'] as String, texto: o['texto'] as String),
    ];
    final segundo = p['segundo'];
    final enunciado = p['enunciado'];
    final correcta = p['correctaId'];
    if (segundo is! num ||
        enunciado is! String ||
        correcta is! String ||
        opciones.length < 2 ||
        !opciones.any((o) => o.id == correcta)) {
      continue;
    }
    final explicacion = p['explicacion'];
    preguntas.add(
      PreguntaVideo(
        id: (p['id'] as String?) ?? 'p${i + 1}',
        segundo: segundo.toInt(),
        enunciado: enunciado,
        opciones: opciones,
        correctaId: correcta,
        explicacion: explicacion is String && explicacion.trim().isNotEmpty
            ? explicacion
            : null,
      ),
    );
  }
  preguntas.sort((a, b) => a.segundo.compareTo(b.segundo));
  return preguntas;
}

Map<String, Object?> preguntaVideoAMapa(PreguntaVideo p) => {
  'id': p.id,
  'segundo': p.segundo,
  'enunciado': p.enunciado,
  'opciones': [
    for (final o in p.opciones) {'id': o.id, 'texto': o.texto},
  ],
  'correctaId': p.correctaId,
  'explicacion': p.explicacion,
};
