import 'package:flutter/material.dart';

import '../../../core/presentation/animaciones.dart';
import '../../../core/presentation/colores_app.dart';
import '../domain/relevancia_seminario.dart';
import '../domain/seminario.dart';
import 'tarjeta_seminario.dart';

/// Seminarios en el inicio: hasta [maximo], primero el que está en vivo,
/// luego los que le ayudan al alumno con algo por reforzar y luego los
/// próximos. Si no hay ninguno para mostrar, no ocupa espacio.
class SeminariosInicio extends StatefulWidget {
  final RepositorioSeminarios repositorio;
  final Map<String, TemaPorReforzar> porReforzar;
  final VoidCallback onVerTodos;
  final DateTime Function() ahora;
  final int maximo;

  const SeminariosInicio({
    super.key,
    required this.repositorio,
    required this.porReforzar,
    required this.onVerTodos,
    this.ahora = DateTime.now,
    this.maximo = 2,
  });

  /// Orden de los seminarios a mostrar (sin pasar de [maximo]).
  static List<Seminario> elegir(
    List<Seminario> todos,
    Map<String, TemaPorReforzar> porReforzar,
    DateTime ahora, {
    int maximo = 2,
  }) {
    int prioridad(Seminario s) {
      final estado = s.estado(ahora);
      final ayuda = ayudaDelSeminario(s, porReforzar) != null;
      return switch (estado) {
        EstadoSeminario.enVivo => 0,
        EstadoSeminario.proximo => ayuda ? 1 : 2,
        // Un grabado solo aparece si le ayuda con algo.
        EstadoSeminario.grabado => ayuda ? 3 : 99,
      };
    }

    final candidatos =
        [
          for (final s in todos)
            if (prioridad(s) < 99) s,
        ]..sort((a, b) {
          final p = prioridad(a).compareTo(prioridad(b));
          return p != 0 ? p : a.fecha.compareTo(b.fecha);
        });
    return candidatos.take(maximo).toList();
  }

  @override
  State<SeminariosInicio> createState() => _SeminariosInicioState();
}

class _SeminariosInicioState extends State<SeminariosInicio> {
  late final Future<List<Seminario>> _seminarios = widget.repositorio
      .listar()
      // Es un complemento del inicio: si falla, simplemente no aparece.
      .onError((_, _) => const <Seminario>[]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Seminario>>(
      future: _seminarios,
      builder: (context, snapshot) {
        final ahora = widget.ahora();
        final elegidos = SeminariosInicio.elegir(
          snapshot.data ?? const [],
          widget.porReforzar,
          ahora,
          maximo: widget.maximo,
        );
        return AnimatedSize(
          duration: sinAnimaciones(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: elegidos.isEmpty
              ? const SizedBox(width: double.infinity)
              : EntradaDifuminada(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Seminarios',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onVerTodos,
                            style: TextButton.styleFrom(
                              foregroundColor: ColoresApp.apagado,
                            ),
                            child: const Text('Ver todos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final s in elegidos)
                        TarjetaSeminario(
                          seminario: s,
                          estado: s.estado(ahora),
                          ayuda: ayudaDelSeminario(s, widget.porReforzar),
                          alAbrir: widget.onVerTodos,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
