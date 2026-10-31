import '../../../student_model/domain/entities/estado_dominio.dart';
import 'recomendacion.dart';

/// Una fila de Mi Ruta con su trazabilidad:
/// evidencias -> dominio estimado (BKT) -> recomendación.
class ItemMiRuta {
  final Recomendacion recomendacion;
  final EstadoDominio estado;
  final int cantidadEvidencias;
  final String? temaId;

  const ItemMiRuta({
    required this.recomendacion,
    required this.estado,
    required this.cantidadEvidencias,
    this.temaId,
  });
}
