import 'package:academiapp_v2/features/assessment/infrastructure/services/correccion_desde_mapa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convierte la respuesta de la Cloud Function', () {
    final correccion = correccionDesdeMapa({
      'intentoId': 'i1',
      'total': 2,
      'correctas': 1,
      'incorrectas': 1,
      'puntaje': 50,
      'detalle': [
        {
          'preguntaId': 'p1',
          'opcionElegidaId': 'a',
          'opcionCorrectaId': 'a',
          'esCorrecta': true,
          'explicacion': 'Bien.',
        },
        {
          'preguntaId': 'p2',
          'opcionElegidaId': null,
          'opcionCorrectaId': 'b',
          'esCorrecta': false,
          'explicacion': null,
        },
      ],
    });

    expect(correccion.intentoId, 'i1');
    expect(correccion.resultado.puntaje, 50.0);
    expect(correccion.resultado.respuestasCorrectas, 1);
    expect(correccion.detalle.first.explicacion, 'Bien.');
    expect(correccion.detalle.last.opcionElegidaId, isNull);
  });
}
