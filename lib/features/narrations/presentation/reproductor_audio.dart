import 'package:audioplayers/audioplayers.dart';

/// Lo que la tarjeta necesita de un reproductor de audio. Así las pruebas
/// usan uno falso (los plugins no corren en flutter test).
abstract class ReproductorAudio {
  Stream<Duration> get posicion;
  Stream<Duration> get duracion;
  Stream<bool> get sonando;
  Stream<void> get terminado;

  /// Carga [url] y empieza desde el inicio.
  Future<void> reproducir(String url);
  Future<void> pausar();
  Future<void> continuar();
  Future<void> irA(Duration posicion);
  Future<void> velocidad(double factor);
  Future<void> liberar();

  /// Reemplazable en pruebas.
  static ReproductorAudio Function() crear = ReproductorAudioPlayers.new;
}

/// Web, Android y escritorio con el paquete audioplayers.
class ReproductorAudioPlayers implements ReproductorAudio {
  final _reproductor = AudioPlayer();

  @override
  Stream<Duration> get posicion => _reproductor.onPositionChanged;

  @override
  Stream<Duration> get duracion => _reproductor.onDurationChanged;

  @override
  Stream<bool> get sonando => _reproductor.onPlayerStateChanged.map(
    (estado) => estado == PlayerState.playing,
  );

  @override
  Stream<void> get terminado => _reproductor.onPlayerComplete;

  @override
  Future<void> reproducir(String url) => _reproductor.play(UrlSource(url));

  @override
  Future<void> pausar() => _reproductor.pause();

  @override
  Future<void> continuar() => _reproductor.resume();

  @override
  Future<void> irA(Duration posicion) => _reproductor.seek(posicion);

  @override
  Future<void> velocidad(double factor) => _reproductor.setPlaybackRate(factor);

  @override
  Future<void> liberar() => _reproductor.dispose();
}
