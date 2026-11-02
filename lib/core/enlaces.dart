/// Enlace válido para una figura: https, o el emulador de Storage en esta
/// computadora (http://localhost) cuando se prueba sin el plan Blaze.
bool esEnlaceImagen(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  if (uri.scheme == 'https') return true;
  return uri.scheme == 'http' &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1');
}
