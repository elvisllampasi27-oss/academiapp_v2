import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Animaciones del panel, livianas a propósito: cada una corre una sola vez
/// al aparecer y, al terminar, deja el contenido sin ningún efecto encima
/// (así no cuestan nada después). Con "reducir animaciones" no corren.

bool sinAnimaciones(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Entra desenfocado y transparente, y se aclara subiendo un poco (como en
/// los paneles modernos).
class EntradaDifuminada extends StatefulWidget {
  final Widget child;
  final Duration retraso;
  final Duration duracion;

  const EntradaDifuminada({
    super.key,
    required this.child,
    this.retraso = Duration.zero,
    this.duracion = const Duration(milliseconds: 500),
  });

  @override
  State<EntradaDifuminada> createState() => _EntradaDifuminadaState();
}

class _EntradaDifuminadaState extends State<EntradaDifuminada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: widget.retraso + widget.duracion,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _control,
    curve: Interval(
      widget.retraso.inMicroseconds /
          (widget.retraso + widget.duracion).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control.isAnimating || _control.isCompleted) return;
    if (sinAnimaciones(context)) {
      _control.value = 1;
    } else {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, hijo) {
        final t = _t.value;
        if (t >= 1) return hijo!;
        final desenfoque = 6 * (1 - t);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: desenfoque < 0.2
                ? hijo
                : ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: desenfoque,
                      sigmaY: desenfoque,
                    ),
                    child: hijo,
                  ),
          ),
        );
      },
    );
  }
}

/// Un valor que cuenta desde 0 hasta su número ("128", "S/ 290", "77 %").
/// Si no tiene número, se muestra tal cual.
class NumeroQueCuenta extends StatefulWidget {
  final String valor;
  final TextStyle estilo;
  final Duration retraso;

  const NumeroQueCuenta(
    this.valor, {
    super.key,
    required this.estilo,
    this.retraso = Duration.zero,
  });

  @override
  State<NumeroQueCuenta> createState() => _NumeroQueCuentaState();
}

class _NumeroQueCuentaState extends State<NumeroQueCuenta>
    with SingleTickerProviderStateMixin {
  static final _numero = RegExp(r'\d+');
  static const _duracion = Duration(milliseconds: 1000);

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: widget.retraso + _duracion,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _control,
    curve: Interval(
      widget.retraso.inMicroseconds /
          (widget.retraso + _duracion).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control.isAnimating || _control.isCompleted) return;
    if (sinAnimaciones(context)) {
      _control.value = 1;
    } else {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _numero.firstMatch(widget.valor);
    if (m == null) return Text(widget.valor, style: widget.estilo);
    final fin = int.parse(m.group(0)!);
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) => Text(
        _t.value >= 1
            ? widget.valor
            : widget.valor.replaceRange(
                m.start,
                m.end,
                '${(fin * _t.value).round()}',
              ),
        style: widget.estilo,
      ),
    );
  }
}

/// Fila de una tabla o lista que entra subiendo y aclarándose, un poco
/// después de la anterior (sin desenfoque: las listas pueden ser largas).
class FilaEntrante extends StatefulWidget {
  final int indice;
  final Widget child;

  const FilaEntrante({super.key, required this.indice, required this.child});

  @override
  State<FilaEntrante> createState() => _FilaEntranteState();
}

class _FilaEntranteState extends State<FilaEntrante>
    with SingleTickerProviderStateMixin {
  static const _duracion = Duration(milliseconds: 380);
  static const _paso = Duration(milliseconds: 45);

  /// Desde la fila 12 ya no se espera más (una lista larga no tarda).
  late final Duration _retraso =
      const Duration(milliseconds: 250) +
      _paso * (widget.indice < 12 ? widget.indice : 12);

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: _retraso + _duracion,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _control,
    curve: Interval(
      _retraso.inMicroseconds / (_retraso + _duracion).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control.isAnimating || _control.isCompleted) return;
    if (sinAnimaciones(context)) {
      _control.value = 1;
    } else {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, hijo) {
        final t = _t.value;
        if (t >= 1) return hijo!;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: hijo,
          ),
        );
      },
    );
  }
}
