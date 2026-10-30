import 'package:academiapp_v2/features/identity/domain/errors/excepcion_autenticacion.dart';
import 'package:academiapp_v2/features/identity/presentation/messages/mensajes_autenticacion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada tipo de error tiene un mensaje para el estudiante', () {
    for (final tipo in TipoErrorAutenticacion.values) {
      final mensaje = mensajeErrorAutenticacion(ExcepcionAutenticacion(tipo));
      expect(mensaje, isNotEmpty);
      expect(mensaje, isNot(contains('Exception')));
    }
  });

  test('usa el mensaje de los StateError del dominio', () {
    expect(
      mensajeErrorAutenticacion(StateError('La cuenta no esta activa.')),
      'La cuenta no esta activa.',
    );
  });

  test('no expone detalles de errores desconocidos', () {
    expect(
      mensajeErrorAutenticacion(Exception('stack interno')),
      'Ocurrió un error inesperado. Inténtalo de nuevo.',
    );
  });
}
