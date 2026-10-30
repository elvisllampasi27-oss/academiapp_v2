import 'package:academiapp_v2/features/identity/domain/errors/excepcion_autenticacion.dart';
import 'package:academiapp_v2/features/identity/infrastructure/services/codigos_error_firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('traduce los codigos de Firebase al dominio', () {
    const casos = {
      'invalid-credential': TipoErrorAutenticacion.credencialesInvalidas,
      'wrong-password': TipoErrorAutenticacion.credencialesInvalidas,
      'user-not-found': TipoErrorAutenticacion.credencialesInvalidas,
      'invalid-email': TipoErrorAutenticacion.correoInvalido,
      'email-already-in-use': TipoErrorAutenticacion.correoEnUso,
      'weak-password': TipoErrorAutenticacion.contrasenaDebil,
      'too-many-requests': TipoErrorAutenticacion.demasiadosIntentos,
      'user-disabled': TipoErrorAutenticacion.cuentaDeshabilitada,
      'network-request-failed': TipoErrorAutenticacion.sinConexion,
      'popup-closed-by-user': TipoErrorAutenticacion.cancelado,
      'cancelled-popup-request': TipoErrorAutenticacion.cancelado,
      'popup-blocked': TipoErrorAutenticacion.ventanaBloqueada,
      'account-exists-with-different-credential':
          TipoErrorAutenticacion.correoEnUso,
      'algo-nuevo': TipoErrorAutenticacion.desconocido,
    };

    casos.forEach((codigo, esperado) {
      expect(traducirCodigoFirebaseAuth(codigo), esperado, reason: codigo);
    });
  });
}
