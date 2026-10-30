import 'package:academiapp_v2/features/identity/domain/services/registrar_estudiante_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes_identidad.dart';

void main() {
  test('el registro guarda la carrera postulada en el perfil', () async {
    final repositorio = RepositorioUsuarioEnMemoria();
    final service = RegistrarEstudianteService(
      servicioAutenticacion: AuthFalsoConfigurable(),
      repositorioUsuario: repositorio,
    );

    final usuario = await service.registrar(
      correo: 'nuevo@academiapp.pe',
      contrasena: 'secreta1',
      nombre: 'Ana Quispe',
      carreraPostulada: 'Ingeniería de Sistemas',
    );

    expect(usuario.carreraPostulada, 'Ingeniería de Sistemas');
    expect(
      repositorio.usuarios['uid-nuevo']?.carreraPostulada,
      'Ingeniería de Sistemas',
    );
  });
}
