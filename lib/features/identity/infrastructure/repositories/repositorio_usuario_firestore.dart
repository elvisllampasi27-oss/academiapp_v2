import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/usuario_academiapp.dart';
import '../../domain/repositories/repositorio_usuario.dart';

class RepositorioUsuarioFirestore implements RepositorioUsuario {
  final FirebaseFirestore firestore;

  RepositorioUsuarioFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      firestore.collection('usuarios');

  @override
  Future<void> guardar(UsuarioAcademiApp usuario) async {
    await _usuarios.doc(usuario.uid).set({
      'correo': usuario.correo,
      'nombre': usuario.nombre,
      'rol': usuario.rol.name,
      'estado': usuario.estado.name,
      'fechaCreacion': Timestamp.fromDate(usuario.fechaCreacion),
      'carreraPostulada': usuario.carreraPostulada,
    });
  }

  @override
  Future<UsuarioAcademiApp?> buscarPorUid(String uid) async {
    final documento = await _usuarios.doc(uid).get();

    if (!documento.exists) {
      return null;
    }

    final datos = documento.data();

    if (datos == null) {
      return null;
    }

    return UsuarioAcademiApp(
      uid: documento.id,
      correo: datos['correo'] as String,
      nombre: datos['nombre'] as String,
      rol: RolUsuario.values.byName(datos['rol'] as String),
      estado: EstadoUsuario.values.byName(datos['estado'] as String),
      fechaCreacion: (datos['fechaCreacion'] as Timestamp).toDate(),
      carreraPostulada: datos['carreraPostulada'] as String?,
    );
  }
}
