import '../../../student_model/domain/entities/parametros_bkt.dart';
import '../../../student_model/domain/repositories/repositorio_evidencia.dart';
import '../../../student_model/domain/services/calcular_estado_dominio_service.dart';
import '../../../student_model/domain/services/modelo_bkt_service.dart';
import '../../../student_model/domain/values/parametros_bkt_iniciales.dart';
import '../entities/item_mi_ruta.dart';
import 'adaptive_engine_service.dart';

/// Evidencias del estudiante -> estado de dominio por habilidad (BKT)
/// -> recomendaciones del motor adaptativo, ordenadas para Mi Ruta.
class ConstruirMiRutaService {
  final RepositorioEvidencia repositorio;
  final ParametrosBkt parametros;
  final CalcularEstadoDominioService calcularDominio;
  final AdaptiveEngineService motor;

  const ConstruirMiRutaService({
    required this.repositorio,
    this.parametros = parametrosBktIniciales,
    this.calcularDominio = const CalcularEstadoDominioService(
      modeloBkt: ModeloBktService(),
    ),
    this.motor = const AdaptiveEngineService(),
  });

  Future<List<ItemMiRuta>> construir({
    required String usuarioId,
    required String matriculaId,
    DateTime? ahora,
  }) async {
    final fecha = ahora ?? DateTime.now();
    final registro = await repositorio.obtenerDeMatricula(
      usuarioId: usuarioId,
      matriculaId: matriculaId,
    );

    final habilidades = registro.evidencias.map((e) => e.habilidadId).toSet();

    final items = <ItemMiRuta>[];

    for (final habilidadId in habilidades) {
      final estado = calcularDominio.calcular(
        matriculaId: matriculaId,
        habilidadId: habilidadId,
        evidencias: registro.evidencias,
        parametros: parametros,
        actualizadoEn: fecha,
      );

      items.add(
        ItemMiRuta(
          recomendacion: motor.generarRecomendacion(
            estadoDominio: estado,
            fecha: fecha,
          ),
          estado: estado,
          cantidadEvidencias: registro.evidencias
              .where((e) => e.habilidadId == habilidadId)
              .length,
          temaId: registro.temaPorHabilidad[habilidadId],
        ),
      );
    }

    // Primero lo más urgente; dentro de cada grupo, el dominio más bajo.
    items.sort((a, b) {
      final porPrioridad = b.recomendacion.prioridad.compareTo(
        a.recomendacion.prioridad,
      );
      return porPrioridad != 0
          ? porPrioridad
          : a.estado.valor.compareTo(b.estado.valor);
    });

    return items;
  }
}
