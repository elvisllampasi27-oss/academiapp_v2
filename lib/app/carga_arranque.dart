import 'package:flutter/material.dart';

import '../core/presentation/carga_puma.dart';

/// Pantalla de arranque: el puma grande se forma mientras se prepara la app
/// (sesión y luego los datos del alumno) y, cuando todo está listo, termina
/// de formarse y recién entra.
///
/// Las pantallas del arranque comparten [avance]: la figura sigue donde iba
/// en vez de empezar de nuevo en cada una.
class CargaArranque extends StatelessWidget {
  static final avance = ValueNotifier<double>(0);

  final bool lista;
  final VoidCallback? alCompletar;

  const CargaArranque({super.key, this.lista = false, this.alCompletar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CargaPuma(
          lista: lista,
          alCompletar: alCompletar,
          avanceCompartido: avance,
          etiqueta: 'Preparando AcademiApp…',
        ),
      ),
    );
  }
}
