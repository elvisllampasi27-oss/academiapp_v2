import 'package:academiapp_v2/admin/contenido/seccion_preguntas_video_admin.dart';
import 'package:academiapp_v2/features/academic/domain/entities/pregunta_video.dart';
import 'package:flutter_test/flutter_test.dart';

const p30 = PreguntaVideo(
  id: 'p1',
  segundo: 30,
  enunciado: '¿2 + 2?',
  opciones: [
    OpcionVideo(id: 'a', texto: '4'),
    OpcionVideo(id: 'b', texto: '5'),
  ],
  correctaId: 'a',
);

void main() {
  test('sale al pasar por su segundo viendo el video, no al saltar', () {
    PreguntaVideo? toca(double a, double b, [Set<String> r = const {}]) =>
        preguntaQueToca([p30], anterior: a, actual: b, respondidas: r);

    expect(toca(29.5, 30), p30);
    expect(toca(29, 29.5), isNull);
    expect(toca(30, 30.5), isNull);
    // Adelantó de un salto: no interrumpe.
    expect(toca(10, 40), isNull);
    // Retrocedió: tampoco.
    expect(toca(40, 29.5), isNull);
    // Ya salió en esta visita.
    expect(toca(29.5, 30, {'p1'}), isNull);
  });

  test('minutos: se escriben y se leen como en YouTube', () {
    expect(segundosDesdeTexto('4:30'), 270);
    expect(segundosDesdeTexto('90'), 90);
    expect(segundosDesdeTexto('1:02:03'), 3723);
    expect(segundosDesdeTexto('4:75'), isNull);
    expect(segundosDesdeTexto('abc'), isNull);
    expect(textoDeSegundos(270), '4:30');
    expect(textoDeSegundos(3723), '1:02:03');
  });

  test('desde Firestore: ordenadas y sin las mal armadas', () {
    final lista = preguntasVideoDesdeMapa({
      'preguntas': [
        preguntaVideoAMapa(p30),
        {
          'id': 'p0',
          'segundo': 10,
          'enunciado': 'Primera',
          'opciones': [
            {'id': 'a', 'texto': 'Sí'},
            {'id': 'b', 'texto': 'No'},
          ],
          'correctaId': 'b',
          'explicacion': 'Porque sí.',
        },
        // Sin alternativas suficientes ni correcta válida: se ignoran.
        {'segundo': 5, 'enunciado': 'x', 'opciones': [], 'correctaId': 'a'},
        {
          'segundo': 6,
          'enunciado': 'y',
          'opciones': [
            {'id': 'a', 'texto': '1'},
            {'id': 'b', 'texto': '2'},
          ],
          'correctaId': 'z',
        },
      ],
    });
    expect(lista.map((p) => p.id), ['p0', 'p1']);
    expect(lista.first.correcta?.texto, 'No');
    expect(lista.first.explicacion, 'Porque sí.');
    expect(lista.last.explicacion, isNull);
    expect(preguntasVideoDesdeMapa(null), isEmpty);
  });

  test('formulario del panel: arma la pregunta o dice qué falta', () {
    ({PreguntaVideo? pregunta, String? error}) armar({
      String tiempo = '1:30',
      String enunciado = '¿Capital del Perú?',
      List<String> opciones = const ['Lima', 'Cusco', '', ''],
      String correcta = 'a',
    }) => preguntaVideoDelFormulario(
      id: 'p9',
      tiempo: tiempo,
      enunciado: enunciado,
      opciones: opciones,
      correcta: correcta,
      explicacion: ' ',
    );

    final ok = armar().pregunta!;
    expect((ok.segundo, ok.opciones.length, ok.explicacion), (90, 2, null));
    expect(armar(tiempo: 'x').error, 'Escribe el minuto así: 4:30.');
    expect(armar(enunciado: ' ').error, 'Escribe la pregunta.');
    expect(
      armar(opciones: const ['Lima', '', '', '']).error,
      'Pon al menos dos alternativas.',
    );
    expect(armar(correcta: 'c').error, 'La correcta tiene que tener texto.');
  });
}
