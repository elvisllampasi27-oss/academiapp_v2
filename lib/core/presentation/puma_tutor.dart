import 'dart:async';

import 'package:flutter/material.dart';

import 'animaciones.dart' show sinAnimaciones;

/// Gestos del puma tutor.
enum GestoPuma {
  /// Atento, mirando al alumno (parpadea de vez en cuando).
  atento,

  /// Mirada hacia arriba: está revisando o pensando la respuesta.
  pensando,

  /// Contento: acertó o le fue bien.
  contento,

  /// Ánimo ante un error: sereno, sin burlarse. Mientras no haya un dibujo
  /// propio de este gesto, usa el del puma serio (nunca uno sonriendo).
  animo,

  /// Serio: una corrección importante, con calma.
  serio,
}

/// El puma tutor de AcademiApp: un dibujo por gesto (sin fondo, todos con
/// el mismo encuadre) que cambia con un fundido corto. Atento, parpadea cada
/// pocos segundos. No hay animaciones que corran todo el rato.
class PumaTutor extends StatefulWidget {
  final GestoPuma gesto;
  final double tamano;

  const PumaTutor({
    super.key,
    this.gesto = GestoPuma.atento,
    this.tamano = 120,
  });

  static String rutaDe(GestoPuma gesto) =>
      'assets/puma/tutor/${switch (gesto) {
        GestoPuma.atento => 'atento',
        GestoPuma.pensando => 'pensando',
        GestoPuma.contento => 'contento',
        GestoPuma.animo || GestoPuma.serio => 'serio',
      }}.webp';

  static const _rutaParpadeo = 'assets/puma/tutor/parpadeo.webp';

  @override
  State<PumaTutor> createState() => _PumaTutorState();
}

class _PumaTutorState extends State<PumaTutor> {
  static const _cadaParpadeo = Duration(seconds: 5);
  static const _duracionParpadeo = Duration(milliseconds: 150);

  Timer? _parpadeos;
  Timer? _finParpadeo;
  bool _parpadeando = false;
  bool _precargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Todos los gestos listos de antemano: al cambiar no hay un hueco.
    if (!_precargado) {
      _precargado = true;
      for (final ruta in {
        for (final g in GestoPuma.values) PumaTutor.rutaDe(g),
        PumaTutor._rutaParpadeo,
      }) {
        precacheImage(AssetImage(ruta), context, onError: (_, _) {});
      }
    }
    _programarParpadeo();
  }

  @override
  void didUpdateWidget(PumaTutor anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.gesto != widget.gesto) _programarParpadeo();
  }

  /// Solo parpadea atento y con las animaciones permitidas.
  void _programarParpadeo() {
    final debe = widget.gesto == GestoPuma.atento && !sinAnimaciones(context);
    if (!debe) {
      _parpadeos?.cancel();
      _parpadeos = null;
      _finParpadeo?.cancel();
      _parpadeando = false;
      return;
    }
    _parpadeos ??= Timer.periodic(_cadaParpadeo, (_) {
      if (!mounted) return;
      setState(() => _parpadeando = true);
      _finParpadeo?.cancel();
      _finParpadeo = Timer(_duracionParpadeo, () {
        if (mounted) setState(() => _parpadeando = false);
      });
    });
  }

  @override
  void dispose() {
    _parpadeos?.cancel();
    _finParpadeo?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _parpadeando && widget.gesto == GestoPuma.atento
        ? PumaTutor._rutaParpadeo
        : PumaTutor.rutaDe(widget.gesto);

    return Semantics(
      image: true,
      label: 'Puma tutor ${widget.gesto.name}',
      child: SizedBox.square(
        dimension: widget.tamano,
        child: AnimatedSwitcher(
          // El parpadeo es instantáneo; los cambios de gesto, un fundido.
          duration: _parpadeando || sinAnimaciones(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          child: Image(
            key: ValueKey(ruta),
            image: AssetImage(ruta),
            width: widget.tamano,
            height: widget.tamano,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
