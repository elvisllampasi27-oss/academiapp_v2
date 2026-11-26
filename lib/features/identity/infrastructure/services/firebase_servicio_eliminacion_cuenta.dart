import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../domain/errors/excepcion_autenticacion.dart';
import '../../domain/repositories/servicio_eliminacion_cuenta.dart';
import '../../domain/values/avisos_eliminacion.dart';
import 'codigos_error_firebase_auth.dart';

class FirebaseServicioEliminacionCuenta implements ServicioEliminacionCuenta {
  final FirebaseAuth auth;
  final FirebaseFunctions functions;

  FirebaseServicioEliminacionCuenta({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : auth = auth ?? FirebaseAuth.instance,
       functions = functions ?? FirebaseFunctions.instance;

  User get _usuario {
    final usuario = auth.currentUser;
    if (usuario == null) {
      throw const ExcepcionEliminacionCuenta(
        'Tu sesión se cerró. Vuelve a ingresar.',
      );
    }
    return usuario;
  }

  @override
  MetodoIngreso metodoIngreso() {
    final proveedores = [
      for (final p in auth.currentUser?.providerData ?? const <UserInfo>[])
        p.providerId,
    ];
    return proveedores.contains('password')
        ? MetodoIngreso.contrasena
        : MetodoIngreso.google;
  }

  @override
  Future<void> reautenticarConContrasena(String contrasena) async {
    final usuario = _usuario;
    final correo = usuario.email;
    if (correo == null) {
      throw const ExcepcionEliminacionCuenta('Tu cuenta no tiene correo.');
    }
    await _traducir(
      () => usuario.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: correo, password: contrasena),
      ),
    );
  }

  @override
  Future<void> reautenticarConGoogle() async {
    final usuario = _usuario;
    final proveedor = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    await _traducir(
      () => kIsWeb
          ? usuario.reauthenticateWithPopup(proveedor)
          : usuario.reauthenticateWithProvider(proveedor),
    );
  }

  @override
  Future<void> eliminarMiCuenta() async {
    try {
      await functions
          .httpsCallable(
            'eliminarMiCuenta',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
          )
          .call<Object?>();
    } on FirebaseFunctionsException catch (e) {
      throw ExcepcionEliminacionCuenta(
        mensajeErrorEliminacion(e.code, e.message),
      );
    }
  }

  Future<void> _traducir(Future<Object?> Function() operacion) async {
    try {
      await operacion();
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'wrong-password' || 'invalid-credential' =>
          const ExcepcionEliminacionCuenta('La contraseña no es correcta.'),
        'user-mismatch' => const ExcepcionEliminacionCuenta(
          'Elige la misma cuenta de Google con la que entraste.',
        ),
        _ => ExcepcionAutenticacion(
          traducirCodigoFirebaseAuth(e.code),
          detalle: e.code,
        ),
      };
    }
  }
}
