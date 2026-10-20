import '../../../student_model/domain/entities/estado_dominio.dart';
import '../entities/recomendacion.dart';

class AdaptiveEngineService {
  const AdaptiveEngineService();

  Recomendacion generarRecomendacion({
    required EstadoDominio estadoDominio,
    required DateTime fecha,
  }) {
    switch (estadoDominio.nivel) {
      case NivelDominio.bajo:
        return Recomendacion(
          id: '${estadoDominio.matriculaId}-${estadoDominio.habilidadId}',
          matriculaId: estadoDominio.matriculaId,
          habilidadId: estadoDominio.habilidadId,
          tipo: TipoRecomendacion.reforzar,
          motivo: 'La habilidad presenta un nivel de dominio bajo.',
          prioridad: 3,
          fecha: fecha,
        );

      case NivelDominio.medio:
        return Recomendacion(
          id: '${estadoDominio.matriculaId}-${estadoDominio.habilidadId}',
          matriculaId: estadoDominio.matriculaId,
          habilidadId: estadoDominio.habilidadId,
          tipo: TipoRecomendacion.practicar,
          motivo: 'La habilidad presenta un nivel de dominio medio.',
          prioridad: 2,
          fecha: fecha,
        );

      case NivelDominio.alto:
        return Recomendacion(
          id: '${estadoDominio.matriculaId}-${estadoDominio.habilidadId}',
          matriculaId: estadoDominio.matriculaId,
          habilidadId: estadoDominio.habilidadId,
          tipo: TipoRecomendacion.profundizar,
          motivo: 'La habilidad presenta un nivel de dominio alto.',
          prioridad: 1,
          fecha: fecha,
        );
    }
  }

  List<Recomendacion> construirMiRuta({
    required List<EstadoDominio> estadosDominio,
    required DateTime fecha,
  }) {
    final recomendaciones = estadosDominio
        .map(
          (estado) => generarRecomendacion(estadoDominio: estado, fecha: fecha),
        )
        .toList();

    recomendaciones.sort((a, b) => b.prioridad.compareTo(a.prioridad));

    return recomendaciones;
  }
}
