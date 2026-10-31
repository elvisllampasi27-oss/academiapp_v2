import '../entities/correccion_intento.dart';
import '../entities/evaluacion.dart';
import '../entities/pregunta.dart';
import '../entities/pregunta_presentada.dart';
import '../repositories/repositorio_evaluacion.dart';
import '../repositories/servicio_correccion_evaluacion.dart';

/// Orquesta la práctica de un tema: qué prácticas hay, sus preguntas
/// y el envío para corrección en el servidor.
class PracticaTemaService {
  final RepositorioEvaluacion repositorio;
  final ServicioCorreccionEvaluacion correccion;

  const PracticaTemaService({
    required this.repositorio,
    required this.correccion,
  });

  /// Prácticas publicadas del tema, de básica a avanzada.
  Future<List<Evaluacion>> listar({
    required String temaId,
    required String versionId,
  }) async {
    final evaluaciones = await repositorio.obtenerPublicadasPorTema(
      temaId: temaId,
      versionId: versionId,
    );

    return evaluaciones
        .where((e) => e.estado == EstadoEvaluacion.publicada)
        .toList()
      ..sort((a, b) => _ordenNivel(a.nivel).compareTo(_ordenNivel(b.nivel)));
  }

  Future<List<PreguntaPresentada>> preguntas(String evaluacionId) async {
    final lista = await repositorio.obtenerPreguntas(evaluacionId);
    return [...lista]..sort((a, b) => a.orden.compareTo(b.orden));
  }

  Future<CorreccionIntento> enviar({
    required String evaluacionId,
    required Map<String, String> respuestas,
    Map<String, int> tiemposMs = const {},
  }) {
    if (respuestas.isEmpty) {
      throw StateError('Responde al menos una pregunta.');
    }

    return correccion.enviar(
      evaluacionId: evaluacionId,
      respuestas: respuestas,
      tiemposMs: tiemposMs,
    );
  }

  static int _ordenNivel(String? nivel) {
    final indice = DificultadPregunta.values.indexWhere((d) => d.name == nivel);
    return indice < 0 ? DificultadPregunta.values.length : indice;
  }
}
