import '../entities/estado_dominio.dart';
import '../entities/evidencia.dart';
import '../entities/parametros_bkt.dart';
import 'modelo_bkt_service.dart';

class CalcularEstadoDominioService {
  final ModeloBktService modeloBkt;

  const CalcularEstadoDominioService({required this.modeloBkt});

  EstadoDominio calcular({
    required String matriculaId,
    required String habilidadId,
    required List<Evidencia> evidencias,
    required ParametrosBkt parametros,
    required DateTime actualizadoEn,
    String modeloVersion = 'bkt-v1',
  }) {
    final evidenciasValidas =
        evidencias
            .where(
              (evidencia) =>
                  evidencia.matriculaId == matriculaId &&
                  evidencia.habilidadId == habilidadId,
            )
            .toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));

    var conocimiento = parametros.conocimientoInicial;

    for (final evidencia in evidenciasValidas) {
      conocimiento = modeloBkt.actualizarConocimiento(
        conocimientoActual: conocimiento,
        respuestaCorrecta: evidencia.resultado == ResultadoEvidencia.correcta,
        parametros: parametros,
      );
    }

    return EstadoDominio(
      matriculaId: matriculaId,
      habilidadId: habilidadId,
      valor: conocimiento,
      nivel: _clasificarNivel(conocimiento),
      modeloVersion: modeloVersion,
      actualizadoEn: actualizadoEn,
    );
  }

  NivelDominio _clasificarNivel(double conocimiento) {
    if (conocimiento < 0.50) {
      return NivelDominio.bajo;
    }

    if (conocimiento < 0.80) {
      return NivelDominio.medio;
    }

    return NivelDominio.alto;
  }
}
