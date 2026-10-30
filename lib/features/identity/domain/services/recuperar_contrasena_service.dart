import '../errors/excepcion_autenticacion.dart';
import '../repositories/servicio_recuperacion_contrasena.dart';
import '../values/validacion_credenciales.dart';

class RecuperarContrasenaService {
  final ServicioRecuperacionContrasena servicio;

  const RecuperarContrasenaService({required this.servicio});

  /// Solicita el correo de restablecimiento.
  ///
  /// Si el correo no está registrado no se informa al usuario (evita revelar
  /// qué cuentas existen); la pantalla muestra siempre el mismo mensaje.
  Future<void> enviar(String correo) async {
    final limpio = correo.trim();

    if (!ValidacionCredenciales.esCorreoValido(limpio)) {
      throw const ExcepcionAutenticacion(TipoErrorAutenticacion.correoInvalido);
    }

    await servicio.enviarCorreoRecuperacion(limpio);
  }
}
