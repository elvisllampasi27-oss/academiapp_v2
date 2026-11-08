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

/// Barra flotante al estilo de la versión anterior: una pastilla de bordes
/// suaves; la pestaña elegida se marca con el celeste del puma (el color de
/// la marca) y muestra su nombre, las demás solo el ícono. Sin desenfoque (dentro de la app los paneles son
/// planos para que los celulares de gama baja vayan fluidos).
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
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xF21A1B22),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0x40FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final (i, pestana) in pestanas.indexed)
              _ItemBarra(
                pestana: pestana,
                activo: i == actual,
                alPresionar: () => alSeleccionar(i),
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

  static const _duracion = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    final duracion = sinAnimaciones(context) ? Duration.zero : _duracion;

    return Semantics(
      button: true,
      selected: activo,
      label: pestana.etiqueta,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: alPresionar,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: duracion,
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minWidth: 46, minHeight: 44),
          padding: EdgeInsets.symmetric(
            horizontal: activo ? 16 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: activo ? const Color(0x2E7CC4FF) : const Color(0x007CC4FF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: activo ? const Color(0x597CC4FF) : const Color(0x007CC4FF),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                pestana.icono,
                size: 22,
                color: activo ? ColoresApp.celeste : Colors.white54,
              ),
              // El nombre aparece (y la pastilla crece) solo en la elegida.
              AnimatedSize(
                duration: duracion,
                curve: Curves.easeOutCubic,
                child: activo
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          pestana.etiqueta,
                          maxLines: 1,
                          style: const TextStyle(
                            color: ColoresApp.celeste,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
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
