/// Id de un video de YouTube desde un enlace (watch, youtu.be, shorts,
/// embed, live) o el id solo. null si no se reconoce.
String? idVideoYoutube(String texto) {
  final t = texto.trim();
  final soloId = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (soloId.hasMatch(t)) return t;
  final uri = Uri.tryParse(t);
  if (uri == null || !uri.hasScheme) return null;
  final host = uri.host.replaceFirst('www.', '').replaceFirst('m.', '');
  String? id;
  if (host == 'youtu.be') {
    id = uri.pathSegments.firstOrNull;
  } else if (host.endsWith('youtube.com')) {
    id =
        uri.queryParameters['v'] ??
        (uri.pathSegments.length >= 2 &&
                const ['shorts', 'embed', 'live'].contains(uri.pathSegments[0])
            ? uri.pathSegments[1]
            : null);
  }
  return id != null && soloId.hasMatch(id) ? id : null;
}

/// Miniatura que YouTube publica para cada video (también los no listados).
String miniaturaYoutube(String videoId) =>
    'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
