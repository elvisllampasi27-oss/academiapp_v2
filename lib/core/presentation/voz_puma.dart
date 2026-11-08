import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Crea la voz con sus avisos: [alCambiar] cuando empieza o termina de hablar
/// y [alPalabra] en cada palabra (para mover la boca del puma).
typedef CrearVozPuma =
    VozPuma Function({
      required void Function(bool hablando) alCambiar,
      required VoidCallback alPalabra,
    });

/// La voz del puma tutor. Opcional: solo habla cuando el alumno lo pide.
abstract class VozPuma {
  /// La que usa la app; las pruebas la reemplazan por una de mentira.
  static CrearVozPuma crear = VozPumaDispositivo.new;

  /// Prepara una voz en español. Devuelve `false` si no hay ninguna (o si el
  /// dispositivo no tiene voz): entonces no se ofrece el botón.
  Future<bool> preparar();

  Future<void> hablar(String texto);

  Future<void> callar();

  /// Calla y deja de avisar (al salir de la pantalla).
  void cerrar();
}

/// Voz con las voces instaladas en el celular o el navegador: gratis y sin
/// enviar el texto a ningún servidor.
class VozPumaDispositivo implements VozPuma {
  final void Function(bool hablando) alCambiar;
  final VoidCallback alPalabra;

  /// Preferencia de acento, de la más cercana a la más lejana.
  static const _acentos = ['es-PE', 'es-419', 'es-US', 'es-MX', 'es-ES'];

  final FlutterTts _tts = FlutterTts();
  bool _cerrada = false;
  bool? _lista;

  VozPumaDispositivo({required this.alCambiar, required this.alPalabra}) {
    _tts.setStartHandler(() => _avisar(true));
    _tts.setCompletionHandler(() => _avisar(false));
    _tts.setCancelHandler(() => _avisar(false));
    _tts.setErrorHandler((_) => _avisar(false));
    _tts.setProgressHandler((_, _, _, _) {
      if (!_cerrada) alPalabra();
    });
  }

  void _avisar(bool hablando) {
    if (!_cerrada) alCambiar(hablando);
  }

  @override
  Future<bool> preparar() async {
    if (_lista case final lista?) return lista;
    try {
      var idiomas = await _idiomas();
      // En el navegador las voces cargan un momento después.
      if (idiomas.isEmpty && kIsWeb) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        idiomas = await _idiomas();
      }
      final elegido = elegirIdioma(idiomas);
      if (elegido == null) return _lista = false;

      await _tts.setLanguage(elegido);
      await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
      await _tts.setPitch(0.95);
      await _tts.awaitSpeakCompletion(false);
      return _lista = true;
    } catch (_) {
      // Sin motor de voz (o en las pruebas): solo texto.
      return _lista = false;
    }
  }

  Future<List<String>> _idiomas() async {
    final lista = await _tts.getLanguages;
    if (lista is! List) return const [];
    return [for (final idioma in lista) ?idioma?.toString()];
  }

  /// El acento preferido que haya; si no, cualquier español.
  @visibleForTesting
  static String? elegirIdioma(List<String> idiomas) {
    String normal(String s) => s.replaceAll('_', '-').toLowerCase();
    for (final acento in _acentos) {
      for (final idioma in idiomas) {
        if (normal(idioma) == acento.toLowerCase()) return idioma;
      }
    }
    for (final idioma in idiomas) {
      if (normal(idioma).startsWith('es')) return idioma;
    }
    return null;
  }

  @override
  Future<void> hablar(String texto) async {
    if (_cerrada || texto.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(texto);
    } catch (_) {
      _avisar(false);
    }
  }

  @override
  Future<void> callar() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Nada que detener.
    } finally {
      _avisar(false);
    }
  }

  @override
  void cerrar() {
    _cerrada = true;
    unawaited(_tts.stop().then<void>((_) {}, onError: (Object _) {}));
  }
}
