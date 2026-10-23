import '../entities/estado_sesion_estudiante.dart';
import 'recuperar_sesion_estudiante_service.dart';

class ResolverEstadoInicialSesionService {
  final RecuperarSesionEstudianteService recuperarSesion;

  ResolverEstadoInicialSesionService({required this.recuperarSesion});

  Future<EstadoSesionEstudiante> resolver() async {
    final usuario = await recuperarSesion.recuperar();

    if (usuario == null) {
      return const EstadoSesionEstudiante.noAutenticado();
    }

    return EstadoSesionEstudiante.autenticado(usuario);
  }
}
