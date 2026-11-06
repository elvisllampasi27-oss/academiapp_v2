import 'package:flutter/material.dart';

import '../core/presentation/colores_app.dart';
import '../core/presentation/animaciones.dart';

class PestanaApp {
  final String etiqueta;
  final IconData icono;
  final Widget contenido;

  const PestanaApp({
    required this.etiqueta,
    required this.icono,
    required this.contenido,
  });
}

/// Estructura de la app ya dentro: 5 pestañas con barra flotante.
/// Cada pestaña se construye recién la primera vez que se abre
/// (menos lecturas a Firestore al entrar) y luego conserva su estado.
class EstudianteShell extends StatefulWidget {
  final List<PestanaApp> pestanas;
  final ValueNotifier<int> indice;

  const EstudianteShell({
    super.key,
    required this.pestanas,
    required this.indice,
  });

  @override
  State<EstudianteShell> createState() => _EstudianteShellState();
}

class _EstudianteShellState extends State<EstudianteShell> {
  final Set<int> _visitadas = {};

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.indice,
      builder: (context, actual, _) {
        _visitadas.add(actual);

        return Scaffold(
          extendBody: true,
          // Al cambiar de pestaña la página reaparece con un desenfoque
          // corto. No se vuelve a crear: conserva su estado y no relee nada.
          body: ReaparicionDifuminada(
            disparo: actual,
            child: IndexedStack(
              index: actual,
              children: [
                for (final (i, pestana) in widget.pestanas.indexed)
                  _visitadas.contains(i)
                      ? pestana.contenido
                      : const SizedBox.shrink(),
              ],
            ),
          ),
          bottomNavigationBar: BarraNavegacionApp(
            pestanas: widget.pestanas,
            actual: actual,
            alSeleccionar: (i) => widget.indice.value = i,
          ),
        );
      },
    );
  }
}

class BarraNavegacionApp extends StatelessWidget {
  final List<PestanaApp> pestanas;
  final int actual;
  final ValueChanged<int> alSeleccionar;

  const BarraNavegacionApp({
    super.key,
    required this.pestanas,
    required this.actual,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: ColoresApp.barra,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ColoresApp.borde),
        ),
        child: Row(
          children: [
            for (final (i, pestana) in pestanas.indexed)
              Expanded(
                child: _ItemBarra(
                  pestana: pestana,
                  activo: i == actual,
                  alPresionar: () => alSeleccionar(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemBarra extends StatelessWidget {
  final PestanaApp pestana;
  final bool activo;
  final VoidCallback alPresionar;

  const _ItemBarra({
    required this.pestana,
    required this.activo,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo ? ColoresApp.texto : ColoresApp.tenue;
    const duracion = Duration(milliseconds: 220);

    return Semantics(
      button: true,
      selected: activo,
      label: pestana.etiqueta,
      excludeSemantics: true,
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(14),
        // La pastilla aparece suave y el ícono crece un poco al activarse.
        child: AnimatedContainer(
          duration: duracion,
          curve: Curves.easeOutCubic,
          height: 52,
          decoration: BoxDecoration(
            color: activo ? const Color(0x1AFFFFFF) : const Color(0x00FFFFFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color),
            duration: duracion,
            builder: (context, tono, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: activo ? 1.08 : 1,
                  duration: duracion,
                  curve: Curves.easeOutBack,
                  child: Icon(pestana.icono, size: 22, color: tono),
                ),
                const SizedBox(height: 3),
                Text(
                  pestana.etiqueta,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    color: tono,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pestaña que todavía no tiene contenido.
class PantallaProximamente extends StatelessWidget {
  final String titulo;
  final String mensaje;

  const PantallaProximamente({
    super.key,
    required this.titulo,
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(mensaje, style: const TextStyle(color: ColoresApp.apagado)),
          ],
        ),
      ),
    );
  }
}
