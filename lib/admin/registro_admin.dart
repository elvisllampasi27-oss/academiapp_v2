import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Entrada del registro de acciones (colección registro_admin). Se escribe
/// en el mismo lote o transacción que el cambio que describe; las reglas
/// exigen el uid del administrador y la hora del servidor.
Map<String, Object?> entradaRegistro(
  FirebaseAuth auth, {
  required String tipo,
  required String descripcion,
  String? usuarioId,
}) => {
  'tipo': tipo,
  'descripcion': descripcion,
  'usuarioId': ?usuarioId,
  'adminUid': auth.currentUser?.uid,
  'adminCorreo': correoAdmin(auth),
  'fecha': FieldValue.serverTimestamp(),
};

String correoAdmin(FirebaseAuth auth) => auth.currentUser?.email ?? 'admin';
