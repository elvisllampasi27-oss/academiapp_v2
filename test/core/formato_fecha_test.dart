import 'package:academiapp_v2/core/presentation/formato_fecha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatea la fecha corta en español', () {
    expect(fechaCorta(DateTime(2026, 10, 31)), 'Sábado 31 oct');
    expect(fechaCorta(DateTime(2026, 11, 2)), 'Lunes 2 nov');
    expect(fechaCorta(DateTime(2026, 9, 6)), 'Domingo 6 set');
  });
}
