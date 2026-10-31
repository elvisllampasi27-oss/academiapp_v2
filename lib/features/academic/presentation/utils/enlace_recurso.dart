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

/// ID de YouTube de un recurso de video, para reproducirlo dentro de la app.
/// Acepta el ID suelto y los enlaces watch, youtu.be, shorts y embed.
/// Devuelve null si no es un video de YouTube.
String? idYoutube(Recurso recurso) {
  if (recurso.tipo != TipoRecurso.video &&
      recurso.tipo != TipoRecurso.grabacion) {
    return null;
  }

  final ubicacion = recurso.ubicacion.trim();
  final esId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  if (esId.hasMatch(ubicacion)) return ubicacion;

  final uri = Uri.tryParse(ubicacion);
  if (uri == null || uri.host.isEmpty) return null;

  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  String? id;

  if (host == 'youtu.be') {
    id = uri.pathSegments.firstOrNull;
  } else if (host == 'youtube.com' || host == 'm.youtube.com') {
    final segmentos = uri.pathSegments;
    if (segmentos.firstOrNull == 'watch') {
      id = uri.queryParameters['v'];
    } else if (segmentos.length >= 2 &&
        const {'shorts', 'embed', 'live'}.contains(segmentos.first)) {
      id = segmentos[1];
    }
  }

  return id != null && esId.hasMatch(id) ? id : null;
}
