import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Crea la voz con sus avisos: [alCambiar] cuando empieza o termina de hablar
/// y [alPalabra] en cada palabra (para mover la boca del puma).
typedef CrearVozPuma = VozPuma Function({
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

      // Voz de hombre si el dispositivo tiene una; un poco más grave y
      // pausada para que suene firme.
      final voz = elegirVoz(await _voces());
      if (voz != null) {
        await _tts.setLanguage(voz.locale);
        await _tts.setVoice({'name': voz.nombre, 'locale': voz.locale});
      }
      final hombre = voz?.esHombre ?? false;
      final natural = voz?.natural ?? false;
      if (kDebugMode) {
        debugPrint(
          'Voz del puma: ${voz?.nombre ?? elegido}'
          '${hombre ? ' (hombre)' : ' (no hay voz de hombre en español)'}',
        );
      }
      // Velocidad y tono normales: bajar el tono deforma la voz (suena áspera
      // y metálica), sobre todo las "Natural", que ya son graves. Solo a una
      // voz de hombre básica se le baja un poco.
      await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
      await _tts.setPitch(hombre && !natural ? 0.93 : 1.0);
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

  Future<List<Map<Object?, Object?>>> _voces() async {
    try {
      final lista = await _tts.getVoices;
      if (lista is! List) return const [];
      return [
        for (final voz in lista)
          if (voz is Map) voz,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Nombres de voces de hombre en español que traen Windows, Edge (las
  /// "Natural"), iOS y otros motores.
  static const _nombresDeHombre = {
    'alex',
    'alvaro',
    'álvaro',
    'andres',
    'andrés',
    'antonio',
    'arnau',
    'carlos',
    'dario',
    'darío',
    'diego',
    'emilio',
    'enrique',
    'federico',
    'gerardo',
    'gonzalo',
    'jorge',
    'javier',
    'juan',
    'liberto',
    'lorenzo',
    'luciano',
    'luis',
    'manuel',
    'marcelo',
    'mario',
    'mateo',
    'nicolas',
    'nicolás',
    'pablo',
    'raul',
    'raúl',
    'ricardo',
    'rodrigo',
    'saul',
    'saúl',
    'sebastian',
    'sebastián',
    'tomas',
    'tomás',
    'victor',
    'víctor',
    'yago',
  };

  /// Elige la mejor voz en español: primero de hombre, luego las de mejor
  /// calidad ("Natural", "Neural"...) y luego el acento más cercano.
  @visibleForTesting
  static ({String nombre, String locale, bool esHombre, bool natural})?
  elegirVoz(List<Map<Object?, Object?>> voces) {
    ({String nombre, String locale, bool esHombre, bool natural})? mejor;
    var mejorPuntaje = -1;
    for (final voz in voces) {
      final nombre = voz['name']?.toString() ?? '';
      final locale = voz['locale']?.toString() ?? '';
      final idioma = locale.replaceAll('_', '-').toLowerCase();
      if (nombre.isEmpty || !idioma.startsWith('es')) continue;

      final genero = voz['gender']?.toString().toLowerCase();
      final palabras = nombre
          .toLowerCase()
          .split(RegExp(r'[^a-záéíóúñ]+'))
          .where((p) => p.isNotEmpty);
      final esHombre =
          genero == 'male' ||
          (genero == null &&
              (palabras.any(_nombresDeHombre.contains) ||
                  palabras.contains('male')));

      final calidad = RegExp(
        'natural|neural|online|enhanced|premium',
        caseSensitive: false,
      ).hasMatch(nombre);
      final acento = _acentos.indexWhere((a) => a.toLowerCase() == idioma);

      final puntaje =
          (esHombre ? 100 : 0) +
          (calidad ? 20 : 0) +
          (acento == -1 ? 4 : 10 - acento * 2);
      if (puntaje > mejorPuntaje) {
        mejorPuntaje = puntaje;
        mejor = (
          nombre: nombre,
          locale: locale,
          esHombre: esHombre,
          natural: calidad,
        );
      }
    }
    return mejor;
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
      await _tts.speak(textoParaVoz(texto));
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

/// Prepara un texto para leerlo en voz alta: las fórmulas (LaTeX) se dicen
/// como se leen ("a entre b", "al cuadrado") y se quitan las marcas de
/// formato que la voz leería como símbolos.
String textoParaVoz(String texto) {
  var t = texto;
  // Fracciones y raíces (pueden repetirse o anidarse un nivel).
  final fraccion = RegExp(r'\\[dt]?frac\{([^{}]*)\}\{([^{}]*)\}');
  final raiz = RegExp(r'\\sqrt\{([^{}]*)\}');
  for (var i = 0; i < 3; i++) {
    t = t
        .replaceAllMapped(fraccion, (m) => ' ${m[1]} entre ${m[2]} ')
        .replaceAllMapped(raiz, (m) => ' raíz de ${m[1]} ');
  }
  t = t
      .replaceAll(RegExp(r'\^\{?2\}?'), ' al cuadrado')
      .replaceAll(RegExp(r'\^\{?3\}?'), ' al cubo')
      .replaceAllMapped(RegExp(r'\^\{([^{}]*)\}'), (m) => ' elevado a ${m[1]}')
      .replaceAllMapped(RegExp(r'\^(\w)'), (m) => ' elevado a ${m[1]}')
      .replaceAll(RegExp(r'\\(cdot|times)'), ' por ')
      .replaceAll(r'\div', ' entre ')
      .replaceAll(r'\pi', ' pi ')
      .replaceAll(RegExp(r'\\(leq|le)\b'), ' menor o igual que ')
      .replaceAll(RegExp(r'\\(geq|ge)\b'), ' mayor o igual que ')
      .replaceAll(r'\neq', ' distinto de ')
      .replaceAll('≤', ' menor o igual que ')
      .replaceAll('≥', ' mayor o igual que ')
      .replaceAll('=', ' igual a ')
      .replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ')
      .replaceAll(RegExp(r'[{}$*#_`]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  return t.trim();
}
