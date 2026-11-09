import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentation/animaciones.dart';
import '../../../core/presentation/colores_app.dart';
import '../domain/narracion.dart';
import 'reproductor_audio.dart';

/// Narraciones del tema (debajo de la clase). Si no hay ninguna, o no se
/// pudieron leer, no ocupa lugar: son un complemento.
class SeccionNarraciones extends StatefulWidget {
  final RepositorioNarraciones repositorio;
  final String versionId;
  final String temaId;

  /// Al empezar un audio (por ejemplo, para pausar la clase).
  final VoidCallback? alReproducir;

  const SeccionNarraciones({
    super.key,
    required this.repositorio,
    required this.versionId,
    required this.temaId,
    this.alReproducir,
  });

  @override
  State<SeccionNarraciones> createState() => _SeccionNarracionesState();
}

class _SeccionNarracionesState extends State<SeccionNarraciones> {
  late final Future<List<Narracion>> _carga = widget.repositorio
      .delTema(versionId: widget.versionId, temaId: widget.temaId)
      .catchError((Object _) => const <Narracion>[]);

  /// La que suena ahora: al empezar otra, la anterior se pausa.
  final _enCurso = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _enCurso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Narracion>>(
      future: _carga,
      builder: (context, s) {
        final narraciones = s.data ?? const [];
        if (narraciones.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EntradaDifuminada(
                retraso: Duration(milliseconds: 160),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.headphones_outlined,
                        size: 20,
                        color: ColoresApp.celeste,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Narraciones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final (i, n) in narraciones.indexed)
                FilaEntrante(
                  indice: i,
                  child: TarjetaNarracion(
                    key: ValueKey(n.id),
                    narracion: n,
                    enCurso: _enCurso,
                    alReproducir: widget.alReproducir,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Velocidades del botón (se recorren en orden).
const velocidadesNarracion = [1.0, 1.25, 1.5];

String etiquetaVelocidad(double v) =>
    '${v == v.roundToDouble() ? v.toInt() : v}x';

/// "3:05", o "1:02:09" si pasa de una hora.
String formatoTiempo(Duration d) {
  final s = d.inSeconds;
  final (h, m, seg) = (s ~/ 3600, s ~/ 60 % 60, s % 60);
  final dos = seg.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$dos';
  return '$m:$dos';
}

IconData iconoNarracion(String tipo) {
  final t = tipo.toLowerCase();
  if (t.startsWith('cuento')) return Icons.auto_stories_outlined;
  if (t.startsWith('novela')) return Icons.menu_book_outlined;
  if (t.startsWith('leyenda')) return Icons.park_outlined;
  if (t.startsWith('mito')) return Icons.bolt_outlined;
  if (t.startsWith('guerra') || t.contains('batalla')) {
    return Icons.shield_outlined;
  }
  if (t.startsWith('biograf')) return Icons.person_outline;
  if (t.startsWith('historia')) return Icons.history_edu_outlined;
  return Icons.headphones_outlined;
}

class TarjetaNarracion extends StatefulWidget {
  final Narracion narracion;
  final ValueNotifier<String?> enCurso;
  final VoidCallback? alReproducir;

  const TarjetaNarracion({
    super.key,
    required this.narracion,
    required this.enCurso,
    this.alReproducir,
  });

  @override
  State<TarjetaNarracion> createState() => _TarjetaNarracionState();
}

class _TarjetaNarracionState extends State<TarjetaNarracion> {
  /// Se crea al primer toque (no un reproductor por tarjeta de entrada).
  ReproductorAudio? _audio;
  final _suscripciones = <StreamSubscription<Object?>>[];

  bool _sonando = false;
  bool _cargando = false;
  bool _terminado = false;
  bool _error = false;
  Duration _posicion = Duration.zero;
  Duration _duracion = Duration.zero;
  double? _arrastre;
  int _velocidad = 0;

  double get _factor => velocidadesNarracion[_velocidad];

  @override
  void initState() {
    super.initState();
    widget.enCurso.addListener(_otraEmpezo);
  }

  @override
  void dispose() {
    widget.enCurso.removeListener(_otraEmpezo);
    for (final s in _suscripciones) {
      unawaited(s.cancel());
    }
    unawaited(_audio?.liberar());
    super.dispose();
  }

  void _otraEmpezo() {
    if (widget.enCurso.value != widget.narracion.id && _sonando) {
      unawaited(_audio?.pausar());
    }
  }

  ReproductorAudio _crear() {
    final audio = ReproductorAudio.crear();
    _suscripciones.addAll([
      audio.sonando.listen((v) {
        if (mounted) setState(() => _sonando = v);
      }),
      audio.posicion.listen((p) {
        if (mounted) setState(() => _posicion = p);
      }),
      audio.duracion.listen((d) {
        if (mounted) setState(() => _duracion = d);
      }),
      audio.terminado.listen((_) {
        if (!mounted) return;
        setState(() {
          _sonando = false;
          _terminado = true;
          _posicion = _duracion;
        });
      }),
    ]);
    return audio;
  }

  Future<void> _alternar() async {
    if (_sonando) {
      await _audio?.pausar();
      return;
    }

    widget.enCurso.value = widget.narracion.id;
    widget.alReproducir?.call();

    final audio = _audio;
    if (audio != null && !_terminado && !_error) {
      await audio.continuar();
      return;
    }

    // Primera vez (o al volver a escucharla completa).
    final nuevo = audio ?? (_audio = _crear());
    setState(() {
      _cargando = true;
      _error = false;
      _terminado = false;
      _posicion = Duration.zero;
    });
    try {
      await nuevo.reproducir(widget.narracion.url);
      if (_factor != 1) await nuevo.velocidad(_factor);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarVelocidad() {
    setState(() => _velocidad = (_velocidad + 1) % velocidadesNarracion.length);
    if (_audio case final audio?) unawaited(audio.velocidad(_factor));
  }

  void _soltar(double ms) {
    setState(() {
      _arrastre = null;
      _terminado = false;
      _posicion = Duration(milliseconds: ms.round());
    });
    unawaited(_audio?.irA(_posicion));
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.narracion;
    final total = _duracion.inMilliseconds.toDouble();
    final valor = (_arrastre ?? _posicion.inMilliseconds.toDouble())
        .clamp(0.0, total > 0 ? total : 0.0)
        .toDouble();
    final puedeMover = _audio != null && total > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ColoresApp.celeste.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconoNarracion(n.tipo),
                    size: 20,
                    color: ColoresApp.celeste,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        n.tipo,
                        style: const TextStyle(
                          fontSize: 13,
                          color: ColoresApp.apagado,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (n.descripcion case final d?)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 6),
                child: Text(
                  d,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ColoresApp.apagado,
                    height: 1.35,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: _cargando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton.filled(
                          tooltip: _sonando ? 'Pausar' : 'Escuchar',
                          style: IconButton.styleFrom(
                            backgroundColor: ColoresApp.celeste,
                            foregroundColor: ColoresApp.fondo,
                          ),
                          onPressed: _alternar,
                          icon: Icon(
                            _sonando
                                ? Icons.pause_rounded
                                : _terminado
                                ? Icons.replay_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: ColoresApp.celeste,
                          thumbColor: ColoresApp.celeste,
                          inactiveTrackColor: ColoresApp.borde,
                          overlayShape: SliderComponentShape.noOverlay,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: valor,
                          max: total > 0 ? total : 1,
                          onChanged: puedeMover
                              ? (v) => setState(() => _arrastre = v)
                              : null,
                          onChangeEnd: puedeMover ? _soltar : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _error
                                  ? 'No se pudo reproducir'
                                  : formatoTiempo(
                                      Duration(milliseconds: valor.round()),
                                    ),
                              style: TextStyle(
                                fontSize: 12,
                                color: _error
                                    ? ColoresApp.naranja
                                    : ColoresApp.apagado,
                              ),
                            ),
                            Text(
                              total > 0 ? formatoTiempo(_duracion) : '--:--',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ColoresApp.apagado,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _cambiarVelocidad,
                  child: Text(
                    etiquetaVelocidad(_factor),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
