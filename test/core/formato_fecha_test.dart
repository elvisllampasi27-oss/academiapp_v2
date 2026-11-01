import 'package:academiapp_v2/core/presentation/formato_fecha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatea la fecha corta en español', () {
    expect(fechaCorta(DateTime(2026, 10, 31)), 'Sábado 31 oct');
    expect(fechaCorta(DateTime(2026, 11, 2)), 'Lunes 2 nov');
    expect(fechaCorta(DateTime(2026, 9, 6)), 'Domingo 6 set');
  });

  test('formatea la hora como en Peru', () {
    expect(horaCorta(DateTime(2026, 11, 7, 19)), '7:00 p. m.');
    expect(horaCorta(DateTime(2026, 11, 7, 0, 5)), '12:05 a. m.');
    expect(horaCorta(DateTime(2026, 11, 7, 12, 30)), '12:30 p. m.');
  });
}
