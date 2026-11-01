import 'package:academiapp_v2/features/exams/domain/entities/examen.dart';
import 'package:academiapp_v2/features/exams/domain/entities/simulacro.dart';
import 'package:academiapp_v2/features/exams/domain/repositories/repositorio_examenes.dart';
import 'package:academiapp_v2/features/exams/domain/repositories/servicio_examenes.dart';

PreguntaExamen preguntaExamen(String id, {String seccion = 'Matemática'}) {
  return PreguntaExamen(
    id: id,
    numero: 1,
    seccion: seccion,
    enunciado: 'Enunciado $id',
    opciones: const [
      OpcionExamen(id: 'a', texto: 'Opción uno'),
      OpcionExamen(id: 'b', texto: 'Opción dos'),
      OpcionExamen(id: 'c', texto: 'Opción tres'),
    ],
  );
}

final examenExonerados = ExamenPasado(
  id: 'exonerados-2025-11-16',
  tipo: TipoExamen.exonerados,
  fecha: DateTime(2025, 11, 16),
  titulo: 'Exonerados · 16 nov 2025',
  totalPreguntas: 2,
);

class RepositorioExamenesEnMemoria implements RepositorioExamenes {
  final List<ExamenPasado> examenes;
  final List<PreguntaExamen> lista;

  RepositorioExamenesEnMemoria({
    this.examenes = const [],
    this.lista = const [],
  });

  @override
  Future<List<ExamenPasado>> listar() async => examenes;

  @override
  Future<List<PreguntaExamen>> preguntas(String examenId) async => lista;
}

/// La correcta de cada pregunta es siempre la "b".
class ServicioExamenesFalso implements ServicioExamenes {
  final List<PreguntaExamen> preguntasSimulacro;
  Map<String, String>? enviadas;
  ErrorExamen? errorAlIniciar;

  ServicioExamenesFalso({this.preguntasSimulacro = const []});

  @override
  Future<RevisionPregunta> revisar({
    required String preguntaId,
    required String opcionId,
  }) async => RevisionPregunta(
    esCorrecta: opcionId == 'b',
    opcionCorrectaId: 'b',
    solucion: 'Solución de $preguntaId',
  );

  @override
  Future<Simulacro> iniciarSimulacro() async {
    if (errorAlIniciar != null) throw errorAlIniciar!;
    return Simulacro(
      id: 'sim-1',
      duracionSegundos: 2400,
      vence: DateTime(2026, 11, 1, 10, 40),
      preguntas: preguntasSimulacro,
    );
  }

  @override
  Future<ResultadoSimulacro> enviarSimulacro({
    required String simulacroId,
    required Map<String, String> respuestas,
  }) async {
    enviadas = respuestas;
    final detalle = [
      for (final p in preguntasSimulacro)
        DetalleRespuesta(
          preguntaId: p.id,
          opcionElegidaId: respuestas[p.id],
          opcionCorrectaId: 'b',
          esCorrecta: respuestas[p.id] == 'b',
        ),
    ];
    final correctas = detalle.where((d) => d.esCorrecta).length;
    return ResultadoSimulacro(
      correctas: correctas,
      total: detalle.length,
      puntaje: detalle.isEmpty ? 0 : (correctas * 100 ~/ detalle.length),
      tiempoUsadoSegundos: 754,
      porSeccion: [
        ResultadoSeccion(
          nombre: 'Matemática',
          correctas: correctas,
          total: detalle.length,
        ),
      ],
      detalle: detalle,
    );
  }
}
