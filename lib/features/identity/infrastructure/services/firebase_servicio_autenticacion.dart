import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/usuario_autenticado.dart';
import '../../domain/repositories/servicio_autenticacion.dart';

class FirebaseServicioAutenticacion implements ServicioAutenticacion {
  final FirebaseAuth firebaseAuth;

  FirebaseServicioAutenticacion({FirebaseAuth? firebaseAuth})
    : firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Future<UsuarioAutenticado> registrar({
    required String correo,
    required String contrasena,
  }) async {
    final credencial = await firebaseAuth.createUserWithEmailAndPassword(
      email: correo,
      password: contrasena,
    );

    return _convertirUsuario(credencial.user);
  }

  @override
  Future<UsuarioAutenticado> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final credencial = await firebaseAuth.signInWithEmailAndPassword(
      email: correo,
      password: contrasena,
    );

    return _convertirUsuario(credencial.user);
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

  UsuarioAutenticado _convertirUsuario(User? usuario) {
    if (usuario == null) {
      throw StateError('Firebase no devolvio un usuario autenticado.');
    }

    return UsuarioAutenticado(uid: usuario.uid, correo: usuario.email);
  }
}
