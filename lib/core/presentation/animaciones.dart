import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Animaciones compartidas por el panel y la app, livianas a propósito: cada
/// una corre una sola vez al aparecer y, al terminar, sus efectos quedan
/// neutros (opacidad 1, sin desplazamiento, desenfoque apagado), así no
/// cuestan nada después.
///
/// Importante: el árbol de widgets NUNCA cambia de forma al terminar. Si los
/// envoltorios se quitaran, Flutter volvería a montar el contenido desde cero
/// y todo lo que tiene estado adentro se reiniciaría (un StreamBuilder se
/// volvería a suscribir a Firestore, un campo de texto perdería lo escrito).
///
/// Con "reducir animaciones" no corren.

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
        final desenfoque = 6 * (1 - t);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: ImageFiltered(
              enabled: desenfoque >= 0.2,
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

  /// Si se da, reemplaza la espera calculada con [indice] (p. ej. cero para
  /// un mensaje nuevo del chat, que debe aparecer ya).
  final Duration? retraso;

  const FilaEntrante({
    super.key,
    required this.indice,
    required this.child,
    this.retraso,
  });

  @override
  State<FilaEntrante> createState() => _FilaEntranteState();
}

class _FilaEntranteState extends State<FilaEntrante>
    with SingleTickerProviderStateMixin {
  static const _duracion = Duration(milliseconds: 380);
  static const _paso = Duration(milliseconds: 45);

  /// Desde la fila 12 ya no se espera más (una lista larga no tarda).
  late final Duration _retraso =
      widget.retraso ??
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

/// Hace que los bloques de una pantalla entren uno tras otro: los primeros
/// [difuminados] entran desenfocados ([EntradaDifuminada]) y el resto, que
/// suelen ser filas de una lista, solo suben y se aclaran ([FilaEntrante]).
/// Los espacios (`SizedBox` vacíos) se dejan tal cual. Si un hijo tiene
/// clave, su envoltorio también: así, al cambiar la lista (p. ej. otro
/// filtro), lo nuevo entra con animación y lo que ya estaba no se repite.
List<Widget> enCascada(List<Widget> hijos, {int difuminados = 6}) {
  var i = 0;
  return [
    for (final hijo in hijos)
      if (hijo is SizedBox && hijo.child == null)
        hijo
      else if (i++ < difuminados)
        EntradaDifuminada(
          key: hijo.key == null ? null : ValueKey(hijo.key),
          retraso: Duration(milliseconds: 80 * (i - 1)),
          child: hijo,
        )
      else
        FilaEntrante(
          key: hijo.key == null ? null : ValueKey(hijo.key),
          indice: i - 1 - difuminados,
          child: hijo,
        ),
  ];
}

/// Barra de avance que se llena desde cero al aparecer y, si su valor
/// cambia, avanza suave hasta el nuevo.
class BarraProgreso extends StatelessWidget {
  final double valor;
  final double minHeight;
  final Color? color;
  final Color? fondo;
  final double radio;

  const BarraProgreso({
    super.key,
    required this.valor,
    this.minHeight = 4,
    this.color,
    this.fondo,
    this.radio = 99,
  });

  @override
  Widget build(BuildContext context) {
    final fin = valor.isFinite ? valor.clamp(0, 1).toDouble() : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fin),
        duration: sinAnimaciones(context)
            ? Duration.zero
            : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: minHeight,
          color: color,
          backgroundColor: fondo,
        ),
      ),
    );
  }
}

/// El ✓ aparece con un rebote; la ✗ aparece y se sacude una vez.
/// Corre una sola vez y queda quieto.
class IconoVeredicto extends StatefulWidget {
  final bool correcta;
  final Color color;
  final double? tamano;
  final Duration retraso;

  const IconoVeredicto({
    super.key,
    required this.correcta,
    required this.color,
    this.tamano,
    this.retraso = Duration.zero,
  });

  @override
  State<IconoVeredicto> createState() => _IconoVeredictoState();
}

class _IconoVeredictoState extends State<IconoVeredicto>
    with SingleTickerProviderStateMixin {
  static const _duracion = Duration(milliseconds: 700);

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: widget.retraso + _duracion,
  );

  /// Parte del tiempo total en que empieza a moverse.
  late final double _inicio =
      widget.retraso.inMicroseconds /
      (widget.retraso + _duracion).inMicroseconds;

  late final double _mitad = _inicio + (1 - _inicio) * 0.5;

  late final Animation<double> _aparece = CurvedAnimation(
    parent: _control,
    curve: Interval(_inicio, _mitad, curve: Curves.easeOutBack),
  );
  late final Animation<double> _sacude = CurvedAnimation(
    parent: _control,
    curve: Interval(_mitad, 1),
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
      animation: _control,
      child: Icon(
        widget.correcta ? Icons.check_circle : Icons.cancel,
        color: widget.color,
        size: widget.tamano,
      ),
      builder: (context, icono) {
        final s = _sacude.value;
        // Tres vaivenes que se apagan; en 0 y en 1 queda en su lugar.
        final dx = widget.correcta
            ? 0.0
            : math.sin(s * math.pi * 6) * 4 * (1 - s);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: _aparece.value.clamp(0, 1.3).toDouble(),
            child: icono,
          ),
        );
      },
    );
  }
}

/// Un "golpe" corto cada vez que [disparo] cambia: [Golpe.pulso] se hunde
/// y vuelve (al elegir, al acertar); [Golpe.sacudida] tiembla de lado (al
/// fallar). Sin cambios, no hace nada.
enum Golpe { ninguno, pulso, sacudida }

class Reaccion extends StatefulWidget {
  final Golpe golpe;

  /// Al cambiar este valor se reproduce [golpe].
  final Object? disparo;
  final Widget child;

  const Reaccion({
    super.key,
    required this.golpe,
    required this.disparo,
    required this.child,
  });

  @override
  State<Reaccion> createState() => _ReaccionState();
}

class _ReaccionState extends State<Reaccion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  @override
  void didUpdateWidget(Reaccion anterior) {
    super.didUpdateWidget(anterior);
    if (widget.disparo != anterior.disparo &&
        widget.golpe != Golpe.ninguno &&
        !sinAnimaciones(context)) {
      _control.forward(from: 0);
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
      animation: _control,
      child: widget.child,
      builder: (context, hijo) {
        final t = _control.value;
        final escala = widget.golpe == Golpe.pulso
            ? 1 - 0.035 * math.sin(t * math.pi)
            : 1.0;
        final dx = widget.golpe == Golpe.sacudida
            ? math.sin(t * math.pi * 6) * 5 * (1 - t)
            : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(scale: escala, child: hijo),
        );
      },
    );
  }
}
