import 'package:academiapp_v2/features/assessment/infrastructure/services/servicio_correccion_cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('muestra los mensajes que el servidor escribio para el estudiante', () {
    expect(
      mensajeErrorCorreccion('failed-precondition', 'Tema no publicado.'),
      'Tema no publicado.',
    );
  });

  test('no muestra errores internos en crudo', () {
    expect(
      mensajeErrorCorreccion('internal', 'INTERNAL'),
      'Ocurrió un error al corregir la práctica. Inténtalo de nuevo.',
    );
    expect(
      mensajeErrorCorreccion('unavailable', null),
      'No hay conexión con el servidor. Inténtalo de nuevo.',
    );
  });
}
