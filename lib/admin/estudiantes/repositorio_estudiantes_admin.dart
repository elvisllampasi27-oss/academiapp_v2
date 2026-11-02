import '../../features/academic/domain/entities/curriculo.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../../features/enrollment/domain/entities/matricula.dart';
import 'modelo_estudiantes.dart';

/// Lo que el panel lee y cambia de los estudiantes. Cada cambio deja una
/// entrada en el registro de acciones, en la misma escritura.
abstract class RepositorioEstudiantesAdmin {
  Future<List<EstudianteAdmin>> estudiantes();

  Future<List<VersionAcademica>> versiones();

  Future<Curriculo> curriculo(String versionId);

  Future<List<AccionAdmin>> accionesRecientes({int limite = 8});

  /// Prácticas y exámenes tipo admisión por día (últimos [dias] días).
  Future<List<ActividadDia>> actividadReciente({int dias = 14});

  Future<FichaEstudiante> ficha(String uid);

  Future<void> matricular({
    required EstudianteAdmin estudiante,
    required VersionAcademica version,
    required DateTime fechaMatricula,
    required DateTime inicio,
  });

  Future<void> cambiarInicio({
    required EstudianteAdmin estudiante,
    required Matricula matricula,
    required DateTime inicio,
  });

  Future<void> cambiarEstado({
    required EstudianteAdmin estudiante,
    required Matricula matricula,
    required EstadoMatricula estado,
  });
}
