import 'dart:async';

import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Una línea de noticias a la vez que sube cada pocos segundos. Al tocarla
/// se detiene (y sigue al tocar de nuevo). Con "reducir animaciones" se
/// queda en la primera línea.
class MarquesinaVertical extends StatefulWidget {
  final List<(IconData, String)> lineas;
  final Duration cada;

  const MarquesinaVertical({
    super.key,
    required this.lineas,
    this.cada = const Duration(milliseconds: 3500),
  });

  @override
  State<MarquesinaVertical> createState() => _MarquesinaVerticalState();
}

class _MarquesinaVerticalState extends State<MarquesinaVertical> {
  Timer? _reloj;
  int _indice = 0;
  bool _pausada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _programar();
  }

  @override
  void didUpdateWidget(MarquesinaVertical anterior) {
    super.didUpdateWidget(anterior);
    if (_indice >= widget.lineas.length) _indice = 0;
    _programar();
  }

  void _programar() {
    _reloj?.cancel();
    final quieta = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (quieta || _pausada || widget.lineas.length < 2) return;
    _reloj = Timer.periodic(widget.cada, (_) {
      if (mounted) {
        setState(() => _indice = (_indice + 1) % widget.lineas.length);
      }
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lineas.isEmpty) return const SizedBox.shrink();
    final (icono, texto) = widget.lineas[_indice];
    return Semantics(
      button: true,
      label: _pausada ? 'Noticias en pausa' : 'Noticias',
      child: GestureDetector(
        onTap: () {
          setState(() => _pausada = !_pausada);
          _programar();
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: ColoresApp.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColoresApp.borde),
          ),
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 550),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              // La nueva entra desde abajo y la anterior sale por arriba.
              transitionBuilder: (hijo, animacion) {
                final entra = hijo.key == ValueKey(_indice);
                final desde = entra ? const Offset(0, 1) : const Offset(0, -1);
                return SlideTransition(
                  position: Tween(
                    begin: desde,
                    end: Offset.zero,
                  ).animate(animacion),
                  child: FadeTransition(opacity: animacion, child: hijo),
                );
              },
              layoutBuilder: (actual, anteriores) => Stack(
                alignment: Alignment.centerLeft,
                children: [...anteriores, ?actual],
              ),
              child: Row(
                key: ValueKey(_indice),
                children: [
                  Icon(icono, size: 18, color: ColoresApp.ambar),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_pausada)
                    const Icon(
                      Icons.pause,
                      size: 16,
                      color: ColoresApp.apagado,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
