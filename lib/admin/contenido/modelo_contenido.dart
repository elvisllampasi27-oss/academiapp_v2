import '../../core/enlaces.dart';
import '../../features/academic/domain/entities/curriculo.dart';
import '../../core/presentation/video/id_youtube.dart';

/// Material de los temas tal como lo administra el panel (Dart puro).

enum NivelQuiz {
  basica('Básico'),
  intermedia('Intermedio'),
  avanzada('Avanzado');

  final String etiqueta;
  const NivelQuiz(this.etiqueta);
}

String idEvaluacion(String versionId, String temaId, NivelQuiz nivel) =>
    '${versionId}__${temaId}__practica-${nivel.name}';

String idPregunta(String evaluacionId, int orden) =>
    '${evaluacionId}__p${orden.toString().padLeft(2, '0')}';

/// Resumen de un quiz de un nivel: estado y cuántas preguntas tiene.
class QuizTema {
  final NivelQuiz nivel;
  final bool publicado;
  final int preguntas;

  const QuizTema(
    this.nivel, {
    required this.publicado,
    required this.preguntas,
  });
}

/// Todo el material de un tema en una versión.
class MaterialTema {
  final String temaId;
  final String? video;
  final String? separata;
  final List<String> contenidos;
  final Map<NivelQuiz, QuizTema> quizzes;

  const MaterialTema({
    required this.temaId,
    this.video,
    this.separata,
    this.contenidos = const [],
    this.quizzes = const {},
  });

  bool get tieneQuiz =>
      quizzes.values.any((q) => q.publicado && q.preguntas > 0);
  bool get quizBorrador =>
      quizzes.values.any((q) => !q.publicado && q.preguntas > 0);

  /// Video, separata, contenidos y quiz: cada uno vale 1/4.
  double get completo =>
      [
        video != null,
        separata != null,
        contenidos.isNotEmpty,
        tieneQuiz,
      ].where((x) => x).length /
      4;
}

/// Material completo de un curso (promedio de sus temas).
double completoCurso(
  String cursoId,
  Curriculo curriculo,
  Map<String, MaterialTema> material,
) {
  final temas = curriculo.temas.where((t) => t.cursoId == cursoId).toList();
  if (temas.isEmpty) return 0;
  final suma = temas.fold<double>(
    0,
    (s, t) => s + (material[t.id]?.completo ?? 0),
  );
  return suma / temas.length;
}

enum FiltroTemas {
  todos('Todos'),
  faltaMaterial('Falta material'),
  sinPublicar('Sin publicar'),
  quizBorrador('Quiz por aprobar');

  final String etiqueta;
  const FiltroTemas(this.etiqueta);
}

bool pasaFiltro(FiltroTemas filtro, MaterialTema? m, bool publicado) =>
    switch (filtro) {
      FiltroTemas.todos => true,
      FiltroTemas.faltaMaterial => (m?.completo ?? 0) < 1,
      FiltroTemas.sinPublicar => !publicado,
      FiltroTemas.quizBorrador => m?.quizBorrador ?? false,
    };

/// Id de YouTube desde un enlace o el id solo. null si no se reconoce.
String? idYoutube(String texto) => idVideoYoutube(texto);

/// Enlace https válido (para la separata y el material extra).
bool enlaceValido(String texto) {
  final uri = Uri.tryParse(texto.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// Pregunta de práctica con su respuesta (solo el panel ve la clave).
class PreguntaPractica {
  final String enunciado;
  final List<String> opciones;
  final int correcta;
  final String explicacion;

  /// Figura del enunciado (enlace https), si tiene.
  final String? imagen;

  const PreguntaPractica({
    required this.enunciado,
    required this.opciones,
    required this.correcta,
    this.explicacion = '',
    this.imagen,
  });

  static const letras = 'abcdefgh';

  /// null si está bien; si no, qué le falta.
  String? get error {
    if (enunciado.trim().isEmpty) return 'Falta el enunciado.';
    final llenas = opciones.where((o) => o.trim().isNotEmpty).length;
    if (llenas != opciones.length || opciones.length < 2) {
      return 'Completa todas las opciones (mínimo 2).';
    }
    if (correcta < 0 || correcta >= opciones.length) {
      return 'Marca la respuesta correcta.';
    }
    if (imagen != null && !esEnlaceImagen(imagen!)) {
      return 'La imagen debe ser un enlace https.';
    }
    return null;
  }
}
