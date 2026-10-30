import 'package:academiapp_v2/features/identity/domain/errors/excepcion_autenticacion.dart';
import 'package:academiapp_v2/features/identity/domain/services/recuperar_contrasena_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes_identidad.dart';

void main() {
  test('envia el correo de recuperacion limpio de espacios', () async {
    final auth = AuthFalsoConfigurable();
    final service = RecuperarContrasenaService(servicio: auth);

    await service.enviar('  alumno@academiapp.pe ');

    expect(auth.correosRecuperacion, ['alumno@academiapp.pe']);
  });

  test('rechaza un correo con formato invalido sin llamar al proveedor', () {
    final auth = AuthFalsoConfigurable();
    final service = RecuperarContrasenaService(servicio: auth);

    expect(
      () => service.enviar('no-es-correo'),
      throwsA(
        isA<ExcepcionAutenticacion>().having(
          (e) => e.tipo,
          'tipo',
          TipoErrorAutenticacion.correoInvalido,
        ),
      ),
    );
    expect(auth.correosRecuperacion, isEmpty);
  });
}
