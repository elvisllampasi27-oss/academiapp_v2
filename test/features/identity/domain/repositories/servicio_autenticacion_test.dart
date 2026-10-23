import 'package:academiapp_v2/features/identity/domain/entities/usuario_autenticado.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/servicio_autenticacion.dart';
import 'package:flutter_test/flutter_test.dart';

class ServicioAutenticacionFalso implements ServicioAutenticacion {
  UsuarioAutenticado? usuarioActual;

  @override
  Future<UsuarioAutenticado> registrar({
    required String correo,
    required String contrasena,
  }) async {
    usuarioActual = UsuarioAutenticado(uid: 'uid-123', correo: correo);

    return usuarioActual!;
  }

  @override
  Future<UsuarioAutenticado> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    usuarioActual = UsuarioAutenticado(uid: 'uid-123', correo: correo);

    return usuarioActual!;
  }

  @override
  Future<void> cerrarSesion() async {
    usuarioActual = null;
  }

  @override
  Future<void> eliminarUsuarioActual() async {
    usuarioActual = null;
  }

  @override
  UsuarioAutenticado? obtenerUsuarioActual() {
    return usuarioActual;
  }
}

void main() {
  test('permite registrar, consultar y cerrar sesion', () async {
    final servicio = ServicioAutenticacionFalso();

    final usuario = await servicio.registrar(
      correo: 'alumno@academiapp.pe',
      contrasena: 'prueba123',
    );

    expect(usuario.uid, 'uid-123');
    expect(usuario.correo, 'alumno@academiapp.pe');

    expect(servicio.obtenerUsuarioActual()?.uid, 'uid-123');

    await servicio.cerrarSesion();

    expect(servicio.obtenerUsuarioActual(), isNull);
  });
}
