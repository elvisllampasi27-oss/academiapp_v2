import 'package:academiapp_v2/features/assessment/domain/entities/correccion_intento.dart';
import 'package:academiapp_v2/features/assessment/domain/entities/evaluacion.dart';
import 'package:academiapp_v2/features/assessment/domain/entities/pregunta.dart';
import 'package:academiapp_v2/features/assessment/domain/entities/pregunta_presentada.dart';
import 'package:academiapp_v2/features/assessment/domain/entities/resultado_evaluacion.dart';
import 'package:academiapp_v2/features/assessment/domain/repositories/repositorio_evaluacion.dart';
import 'package:academiapp_v2/features/assessment/domain/repositories/servicio_correccion_evaluacion.dart';

Evaluacion evaluacion(
  String id, {
  String? nivel = 'basica',
  EstadoEvaluacion estado = EstadoEvaluacion.publicada,
}) {
  return Evaluacion(
    id: id,
    temaId: 'algebra-02',
    versionId: 'version-1',
    tipo: TipoEvaluacion.practica,
    estado: estado,
    nivel: nivel,
  );
}

PreguntaPresentada pregunta(String id, int orden, String enunciado) {
  return PreguntaPresentada(
    id: id,
    evaluacionId: 'ev',
    enunciado: enunciado,
    dificultad: DificultadPregunta.basica,
    orden: orden,
    opciones: const [
      OpcionPresentada(id: 'a', texto: 'Opción uno'),
      OpcionPresentada(id: 'b', texto: 'Opción dos'),
    ],
  );
}

class RepositorioEvaluacionEnMemoria implements RepositorioEvaluacion {
  final List<Evaluacion> evaluaciones;
  final List<PreguntaPresentada> lista;

  RepositorioEvaluacionEnMemoria({
    this.evaluaciones = const [],
    this.lista = const [],
  });

  @override
  Future<List<Evaluacion>> obtenerPublicadasPorTema({
    required String temaId,
    required String versionId,
  }) async => evaluaciones;

  @override
  Future<List<PreguntaPresentada>> obtenerPreguntas(
    String evaluacionId,
  ) async => lista;
}

/// Simula al servidor: conoce las claves y corrige.
class CorreccionFalsa implements ServicioCorreccionEvaluacion {
  final Map<String, String> claves;
  String? errorServidor;
  Map<String, String>? ultimasRespuestas;

  CorreccionFalsa(this.claves);

  @override
  Future<CorreccionIntento> enviar({
    required String evaluacionId,
    required Map<String, String> respuestas,
    required Map<String, int> tiemposMs,
  }) async {
    if (errorServidor != null) throw StateError(errorServidor!);
    ultimasRespuestas = respuestas;

    final detalle = [
      for (final entrada in claves.entries)
        CorreccionPregunta(
          preguntaId: entrada.key,
          opcionElegidaId: respuestas[entrada.key],
          opcionCorrectaId: entrada.value,
          esCorrecta: respuestas[entrada.key] == entrada.value,
          explicacion: 'Explicación de ${entrada.key}',
        ),
    ];
    final correctas = detalle.where((d) => d.esCorrecta).length;

    return CorreccionIntento(
      intentoId: 'intento-1',
      resultado: ResultadoEvaluacion(
        totalPreguntas: detalle.length,
        respuestasCorrectas: correctas,
        respuestasIncorrectas: detalle.length - correctas,
        puntaje: correctas / detalle.length * 100,
      ),
      detalle: detalle,
    );
  }
}
