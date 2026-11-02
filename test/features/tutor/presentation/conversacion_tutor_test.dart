import 'package:academiapp_v2/features/tutor/domain/entities/mensaje_tutor.dart';
import 'package:academiapp_v2/features/tutor/domain/entities/respuesta_tutor.dart';
import 'package:academiapp_v2/features/tutor/domain/exceptions/error_tutor.dart';
import 'package:academiapp_v2/features/tutor/domain/repositories/servicio_tutor.dart';
import 'package:academiapp_v2/features/tutor/infrastructure/services/servicio_tutor_cloud_functions.dart';
import 'package:academiapp_v2/features/tutor/presentation/conversacion_tutor.dart';
import 'package:flutter_test/flutter_test.dart';

class TutorFalso implements ServicioTutor {
  final List<List<MensajeTutor>> historiales = [];
  ErrorTutor? error;

  @override
  Future<RespuestaTutor> preguntar({
    required String versionId,
    required String temaId,
    required String pregunta,
    required List<MensajeTutor> historial,
  }) async {
    historiales.add(historial);
    if (error != null) throw error!;
    return RespuestaTutor(
      texto: 'Respuesta a: $pregunta',
      restantesHoy: 2,
      limiteDiario: 3,
    );
  }
}

void main() {
  late TutorFalso tutor;
  late ConversacionTutor conversacion;

  setUp(() {
    tutor = TutorFalso();
    conversacion = ConversacionTutor(
      servicio: tutor,
      versionId: 'version-1',
      temaId: 'algebra-02',
    );
  });

  test('agrega la pregunta y la respuesta, con las dudas restantes', () async {
    await conversacion.preguntar('  ¿Qué es P(1)?  ');

    expect(conversacion.mensajes.map((m) => m.texto), [
      '¿Qué es P(1)?',
      'Respuesta a: ¿Qué es P(1)?',
    ]);
    expect(conversacion.restantesHoy, 2);
    expect(conversacion.limiteDiario, 3);
    expect(conversacion.pensando, isFalse);
    // La primera pregunta va sin historial; la segunda lleva la anterior.
    await conversacion.preguntar('¿Y el término independiente?');
    expect(tutor.historiales.first, isEmpty);
    expect(tutor.historiales.last, hasLength(2));
  });

  test('el historial enviado se limita a los ultimos turnos', () async {
    for (var i = 0; i < 5; i++) {
      await conversacion.preguntar('duda $i');
    }

    expect(
      tutor.historiales.last,
      hasLength(ConversacionTutor.maximoHistorial),
    );
  });

  test('un error del servidor se muestra y no rompe la conversacion', () async {
    tutor.error = const ErrorTutor('Ya usaste tus 3 dudas de hoy.');

    await conversacion.preguntar('otra duda');

    expect(conversacion.error, 'Ya usaste tus 3 dudas de hoy.');
    expect(conversacion.pensando, isFalse);
    expect(conversacion.mensajes.single.autor, AutorMensaje.estudiante);
  });

  test('ignora preguntas vacias', () async {
    await conversacion.preguntar('   ');

    expect(conversacion.mensajes, isEmpty);
    expect(tutor.historiales, isEmpty);
  });

  test('mensajes de error del servidor: propios o genericos', () {
    expect(
      mensajeErrorTutor('resource-exhausted', 'Ya usaste tus 3 dudas.'),
      'Ya usaste tus 3 dudas.',
    );
    expect(
      mensajeErrorTutor('internal', 'stack trace feo'),
      'El tutor no pudo responder. Inténtalo de nuevo.',
    );
    expect(
      mensajeErrorTutor('unavailable', null),
      'No hay conexión con el tutor. Inténtalo de nuevo.',
    );
  });

  test('lee la respuesta de la funcion', () {
    final respuesta = respuestaDesdeMapa({
      'respuesta': ' P(1) = 7 ',
      'restantesHoy': 1,
      'limiteDiario': 3,
    });

    expect(respuesta.texto, 'P(1) = 7');
    expect(respuesta.restantesHoy, 1);
    expect(
      () => respuestaDesdeMapa({'respuesta': ''}),
      throwsA(isA<ErrorTutor>()),
    );
  });
}
