import '../../domain/entities/recurso.dart';

/// Convierte la `ubicacion` de un recurso en un enlace abrible.
///
/// Acepta URLs completas (https://...) y, por compatibilidad con V1,
/// un ID suelto de YouTube en recursos de tipo video.
/// Devuelve null si la ubicación no es un enlace seguro.
Uri? enlaceDeRecurso(Recurso recurso) {
  final ubicacion = recurso.ubicacion.trim();

  if (ubicacion.isEmpty) return null;

  final esIdYoutube = RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(ubicacion);

  if (recurso.tipo == TipoRecurso.video && esIdYoutube) {
    return Uri.https('www.youtube.com', '/watch', {'v': ubicacion});
  }

  final uri = Uri.tryParse(ubicacion);

  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;

  return uri;
}
