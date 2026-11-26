/// Enlace válido para una figura: https, o el emulador de Storage en esta
/// computadora (http://localhost) cuando se prueba sin el plan Blaze.
bool esEnlaceImagen(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  if (uri.scheme == 'https') return true;
  return uri.scheme == 'http' &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1');
}

/// Política de privacidad publicada en Firebase Hosting
/// (hosting/privacidad/index.html). Play Store pide este enlace.
const enlacePoliticaPrivacidad =
    'https://academiapp-v2-7b9ce.web.app/privacidad/';

/// Pago de Premium en la web con Culqi (hosting/premium/). Solo se abre
/// desde la versión web: en Android, Google Play no permite enlazar a otro
/// medio de pago.
const enlacePagoWeb = 'https://academiapp-v2-7b9ce.web.app/premium/';
