import 'package:flutter/material.dart';

import '../core/presentation/carga_puma.dart';
import '../core/presentation/colores_app.dart';

/// Pantalla de arranque: el puma grande se forma mientras se prepara la app
/// (sesión y luego los datos del alumno) y, cuando todo está listo, termina
/// de formarse y recién entra.
///
/// Las pantallas del arranque comparten [avance]: la figura sigue donde iba
/// en vez de empezar de nuevo en cada una.
class CargaArranque extends StatelessWidget {
  static final avance = ValueNotifier<double>(0);

  /// Ancho del puma. La bienvenida lo toma desde aquí para llevarlo al fondo
  /// sin saltos (por eso el puma va justo al centro y el texto aparte).
  static const anchoPuma = 220.0;

  final bool lista;
  final VoidCallback? alCompletar;

  const CargaArranque({super.key, this.lista = false, this.alCompletar});

  @override
  Widget build(BuildContext context) {
    const altoPuma = anchoPuma / (659 / 624);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: CargaPuma(
              lista: lista,
              alCompletar: alCompletar,
              avanceCompartido: avance,
              tamano: anchoPuma,
              etiqueta: 'Preparando AcademiApp',
              mostrarEtiqueta: false,
            ),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, altoPuma / 2 + 30),
              child: const ExcludeSemantics(
                child: Text(
                  'Preparando AcademiApp…',
                  style: TextStyle(
                    color: ColoresApp.apagado,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
