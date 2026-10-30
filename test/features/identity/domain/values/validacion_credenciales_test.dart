import 'package:academiapp_v2/features/identity/domain/values/carreras_unsch.dart';
import 'package:academiapp_v2/features/identity/domain/values/validacion_credenciales.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valida formato de correo', () {
    expect(ValidacionCredenciales.esCorreoValido('a@b.pe'), isTrue);
    expect(ValidacionCredenciales.esCorreoValido(' a@b.pe '), isTrue);
    expect(ValidacionCredenciales.esCorreoValido('a@b'), isFalse);
    expect(ValidacionCredenciales.esCorreoValido('ab.pe'), isFalse);
    expect(ValidacionCredenciales.esCorreoValido(''), isFalse);
  });

  test('exige longitud minima de contrasena', () {
    expect(ValidacionCredenciales.esContrasenaValida('12345'), isFalse);
    expect(ValidacionCredenciales.esContrasenaValida('123456'), isTrue);
  });

  test('la lista de carreras no tiene duplicados', () {
    expect(carrerasUnsch.toSet().length, carrerasUnsch.length);
  });
}
