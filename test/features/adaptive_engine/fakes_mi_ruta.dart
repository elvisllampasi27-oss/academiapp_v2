import 'package:academiapp_v2/features/student_model/domain/entities/evidencia.dart';
import 'package:academiapp_v2/features/student_model/domain/repositories/repositorio_evidencia.dart';

class RepositorioEvidenciaEnMemoria implements RepositorioEvidencia {
  final List<Evidencia> evidencias;
  final Map<String, String> temaPorHabilidad;

  RepositorioEvidenciaEnMemoria(
    this.evidencias, [
    this.temaPorHabilidad = const {},
  ]);

  @override
  Future<RegistroEvidencias> obtenerDeMatricula({
    required String usuarioId,
    required String matriculaId,
  }) async => RegistroEvidencias(
    evidencias: evidencias,
    temaPorHabilidad: temaPorHabilidad,
  );
}

/// Genera evidencias de una habilidad a partir de una secuencia de aciertos.
List<Evidencia> evidenciasDe(String habilidadId, List<bool> aciertos) {
  return [
    for (final (i, acierto) in aciertos.indexed)
      Evidencia(
        id: '$habilidadId-$i',
        matriculaId: 'm1',
        respuestaId: 'r$i',
        habilidadId: habilidadId,
        origen: OrigenEvidencia.practica,
        resultado: acierto
            ? ResultadoEvidencia.correcta
            : ResultadoEvidencia.incorrecta,
        dificultad: DificultadEvidencia.basica,
        numeroIntento: 1,
        ayudaUtilizada: false,
        fecha: DateTime(2026, 10, 31, 10, i),
      ),
  ];
}
