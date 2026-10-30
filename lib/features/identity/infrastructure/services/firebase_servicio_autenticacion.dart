import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../domain/entities/usuario_autenticado.dart';
import '../../domain/errors/excepcion_autenticacion.dart';
import '../../domain/repositories/servicio_autenticacion.dart';
import '../../domain/repositories/servicio_autenticacion_google.dart';
import '../../domain/repositories/servicio_recuperacion_contrasena.dart';
import 'codigos_error_firebase_auth.dart';

class FirebaseServicioAutenticacion
    implements
        ServicioAutenticacion,
        ServicioRecuperacionContrasena,
        ServicioAutenticacionGoogle {
  final FirebaseAuth firebaseAuth;

  FirebaseServicioAutenticacion({FirebaseAuth? firebaseAuth})
    : firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Future<UsuarioAutenticado> registrar({
    required String correo,
    required String contrasena,
  }) async {
    final credencial = await _traducirErrores(
      () => firebaseAuth.createUserWithEmailAndPassword(
        email: correo,
        password: contrasena,
      ),
    );

    return _convertirUsuario(credencial.user);
  }

  @override
  Future<UsuarioAutenticado> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final credencial = await _traducirErrores(
      () => firebaseAuth.signInWithEmailAndPassword(
        email: correo,
        password: contrasena,
      ),
    );

    return _convertirUsuario(credencial.user);
  }

  @override
  Future<UsuarioAutenticado> iniciarConGoogle() async {
    final proveedor = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});

    // Web: ventana emergente de Google. Móvil: flujo del proveedor de
    // Firebase (no requiere el paquete google_sign_in).
    final credencial = await _traducirErrores(
      () => kIsWeb
          ? firebaseAuth.signInWithPopup(proveedor)
          : firebaseAuth.signInWithProvider(proveedor),
    );

    return _convertirUsuario(credencial.user);
  }

  @override
  Future<void> enviarCorreoRecuperacion(String correo) async {
    await firebaseAuth.setLanguageCode('es');

    try {
      await _traducirErrores(
        () => firebaseAuth.sendPasswordResetEmail(email: correo),
      );
    } on ExcepcionAutenticacion catch (error) {
      // No revelar si el correo existe: solo se propagan errores que el
      // usuario puede corregir o que impiden el envío.
      if (error.tipo == TipoErrorAutenticacion.credencialesInvalidas) {
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> cerrarSesion() {
    return firebaseAuth.signOut();
  }

  @override
  Future<void> eliminarUsuarioActual() async {
    final usuario = firebaseAuth.currentUser;

    if (usuario == null) {
      throw StateError('No existe un usuario autenticado para eliminar.');
    }

    await usuario.delete();
  }

  @override
  UsuarioAutenticado? obtenerUsuarioActual() {
    final usuario = firebaseAuth.currentUser;

    if (usuario == null) {
      return null;
    }

    return UsuarioAutenticado(uid: usuario.uid, correo: usuario.email);
  }

  Future<T> _traducirErrores<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on FirebaseAuthException catch (error) {
      throw ExcepcionAutenticacion(
        traducirCodigoFirebaseAuth(error.code),
        detalle: error.code,
      );
    }
  }

  UsuarioAutenticado _convertirUsuario(User? usuario) {
    if (usuario == null) {
      throw StateError('Firebase no devolvio un usuario autenticado.');
    }

    return UsuarioAutenticado(
      uid: usuario.uid,
      correo: usuario.email,
      nombre: usuario.displayName,
    );
  }
}
