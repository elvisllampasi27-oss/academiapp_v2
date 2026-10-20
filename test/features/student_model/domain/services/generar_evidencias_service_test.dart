import 'package:academiapp_v2/features/assessment/domain/entities/respuesta.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/evidencia.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/pregunta_habilidad.dart';
import 'package:academiapp_v2/features/student_model/domain/services/generar_evidencias_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('genera una evidencia por cada habilidad asociada a la pregunta', () {
    final service = GenerarEvidenciasService();

    const respuesta = Respuesta(
      id: 'respuesta-1',
      intentoId: 'intento-1',
      preguntaId: 'pregunta-1',
      opcionId: 'opcion-2',
      esCorrecta: false,
      tiempoRespuesta: Duration(seconds: 20),
    );

    const relaciones = [
      PreguntaHabilidad(
        preguntaId: 'pregunta-1',
        habilidadId: 'suma-matrices',
        peso: 1.0,
      ),
      PreguntaHabilidad(
        preguntaId: 'pregunta-1',
        habilidadId: 'operaciones-matrices',
        peso: 0.5,
      ),
    ];

    final evidencias = service.generar(
      respuesta: respuesta,
      relaciones: relaciones,
      matriculaId: 'matricula-1',
      origen: OrigenEvidencia.evaluacion,
      dificultad: DificultadEvidencia.intermedia,
      numeroIntento: 1,
      ayudaUtilizada: false,
      fecha: DateTime(2026, 10, 20),
    );

    expect(evidencias.length, 2);

    expect(evidencias[0].habilidadId, 'suma-matrices');
    expect(evidencias[0].resultado, ResultadoEvidencia.incorrecta);

    expect(evidencias[1].habilidadId, 'operaciones-matrices');
    expect(evidencias[1].resultado, ResultadoEvidencia.incorrecta);
  });

  test('ignora relaciones pertenecientes a otras preguntas', () {
    final service = GenerarEvidenciasService();

    const respuesta = Respuesta(
      id: 'respuesta-1',
      intentoId: 'intento-1',
      preguntaId: 'pregunta-1',
      opcionId: 'opcion-1',
      esCorrecta: true,
      tiempoRespuesta: Duration(seconds: 10),
    );

    const relaciones = [
      PreguntaHabilidad(
        preguntaId: 'pregunta-1',
        habilidadId: 'habilidad-1',
        peso: 1.0,
      ),
      PreguntaHabilidad(
        preguntaId: 'pregunta-2',
        habilidadId: 'habilidad-2',
        peso: 1.0,
      ),
    ];

    final evidencias = service.generar(
      respuesta: respuesta,
      relaciones: relaciones,
      matriculaId: 'matricula-1',
      origen: OrigenEvidencia.practica,
      dificultad: DificultadEvidencia.basica,
      numeroIntento: 1,
      ayudaUtilizada: false,
      fecha: DateTime(2026, 10, 20),
    );

    expect(evidencias.length, 1);
    expect(evidencias.single.habilidadId, 'habilidad-1');
    expect(evidencias.single.resultado, ResultadoEvidencia.correcta);
  });
}
