import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'reproductor_clase.dart';

/// Constructor por defecto: la clase se reproduce dentro de la app.
Widget reproductorYoutube({
  required String videoId,
  required double inicio,
  required ControlClase control,
  required AlAvanzarClase alAvanzar,
}) {
  return ReproductorYoutube(
    key: ValueKey(videoId),
    videoId: videoId,
    inicio: inicio,
    control: control,
    alAvanzar: alAvanzar,
  );
}

class ReproductorYoutube extends StatefulWidget {
  final String videoId;

  /// Segundo desde el que continúa (lo que ya había visto).
  final double inicio;
  final ControlClase control;
  final AlAvanzarClase alAvanzar;

  const ReproductorYoutube({
    super.key,
    required this.videoId,
    required this.inicio,
    required this.control,
    required this.alAvanzar,
  });

  @override
  State<ReproductorYoutube> createState() => _ReproductorYoutubeState();
}

class _ReproductorYoutubeState extends State<ReproductorYoutube> {
  late final YoutubePlayerController _controlador;
  StreamSubscription<YoutubeVideoState>? _suscripcion;
  double _duracion = 0;

  @override
  void initState() {
    super.initState();

    _controlador = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      // Continúa donde se quedó (salvo que esté casi al inicio).
      startSeconds: widget.inicio > 5 ? widget.inicio : null,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
        // 2 lecturas por segundo bastan y cuidan los celulares de gama baja.
        videoStateUpdateInterval: 500,
      ),
    );

    _suscripcion = _controlador.videoStateStream.listen(_alCambiar);
    widget.control.vincular(
      pausar: _controlador.pauseVideo,
      irA: (segundos) {
        _controlador.seekTo(seconds: segundos, allowSeekAhead: true);
        _controlador.playVideo();
      },
    );
  }

  Future<void> _alCambiar(YoutubeVideoState estado) async {
    if (_duracion <= 0) {
      final segunMetadatos =
          _controlador.metadata.duration.inMilliseconds / 1000;
      _duracion = segunMetadatos > 0
          ? segunMetadatos
          : await _controlador.duration;
    }

    if (!mounted) return;

    widget.alAvanzar(estado.position.inMilliseconds / 1000, _duracion);
  }

  @override
  void dispose() {
    widget.control.desvincular();
    _suscripcion?.cancel();
    _controlador.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controlador,
      aspectRatio: 16 / 9,
      backgroundColor: Colors.black,
    );
  }
}
