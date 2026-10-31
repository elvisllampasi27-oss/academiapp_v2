import 'package:academiapp_v2/features/assessment/domain/entities/evaluacion.dart';
import 'package:academiapp_v2/features/assessment/domain/services/practica_tema_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes_practica.dart';

void main() {
  test('lista solo publicadas, de basica a avanzada', () async {
    final service = PracticaTemaService(
      repositorio: RepositorioEvaluacionEnMemoria(
        evaluaciones: [
          evaluacion('av', nivel: 'avanzada'),
          evaluacion('bo', nivel: 'basica', estado: EstadoEvaluacion.borrador),
          evaluacion('ba', nivel: 'basica'),
          evaluacion('in', nivel: 'intermedia'),
        ],
      ),
      correccion: CorreccionFalsa(const {}),
    );

    final lista = await service.listar(
      temaId: 'algebra-02',
      versionId: 'version-1',
    );

    expect(lista.map((e) => e.id), ['ba', 'in', 'av']);
  });

  test('ordena las preguntas por orden', () async {
    final service = PracticaTemaService(
      repositorio: RepositorioEvaluacionEnMemoria(
        lista: [pregunta('p2', 2, 'Segunda'), pregunta('p1', 1, 'Primera')],
      ),
      correccion: CorreccionFalsa(const {}),
    );

    final preguntas = await service.preguntas('ev');

    expect(preguntas.map((p) => p.id), ['p1', 'p2']);
  });

  test('no envia un intento vacio', () {
    final service = PracticaTemaService(
      repositorio: RepositorioEvaluacionEnMemoria(),
      correccion: CorreccionFalsa(const {}),
    );

    expect(
      () => service.enviar(evaluacionId: 'ev', respuestas: const {}),
      throwsStateError,
    );
  });
}
