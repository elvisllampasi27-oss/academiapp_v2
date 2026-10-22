import 'package:academiapp_v2/features/identity/domain/entities/usuario_academiapp.dart';
import 'package:academiapp_v2/features/identity/domain/repositories/repositorio_usuario.dart';
import 'package:flutter_test/flutter_test.dart';

class RepositorioUsuarioFalso implements RepositorioUsuario {
  final Map<String, UsuarioAcademiApp> usuarios = {};

  @override
  Future<void> guardar(UsuarioAcademiApp usuario) async {
    usuarios[usuario.uid] = usuario;
  }

  @override
  Future<UsuarioAcademiApp?> buscarPorUid(String uid) async {
    return usuarios[uid];
  }
}

void main() {
  test('guarda y recupera un usuario por UID', () async {
    final repositorio = RepositorioUsuarioFalso();

    final usuario = UsuarioAcademiApp(
      uid: 'uid-123',
      correo: 'alumno@academiapp.pe',
      nombre: 'Alumno Prueba',
      rol: RolUsuario.estudiante,
      estado: EstadoUsuario.activo,
      fechaCreacion: DateTime(2026, 10, 22),
    );

    await repositorio.guardar(usuario);

    final encontrado = await repositorio.buscarPorUid('uid-123');

    expect(encontrado, isNotNull);
    expect(encontrado!.uid, 'uid-123');
    expect(encontrado.correo, 'alumno@academiapp.pe');
    expect(encontrado.rol, RolUsuario.estudiante);
    expect(encontrado.estado, EstadoUsuario.activo);
  });

  test('devuelve null cuando el UID no existe', () async {
    final repositorio = RepositorioUsuarioFalso();

    final encontrado = await repositorio.buscarPorUid('no-existe');

    expect(encontrado, isNull);
  });
}
