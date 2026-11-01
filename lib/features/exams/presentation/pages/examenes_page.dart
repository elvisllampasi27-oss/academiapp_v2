import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../domain/entities/examen.dart';
import '../../domain/entities/simulacro.dart';
import '../../domain/repositories/repositorio_examenes.dart';
import '../../domain/repositories/servicio_examenes.dart';
import 'practica_examen_page.dart';
import 'simulacro_page.dart';

/// Pestaña Exámenes: el examen tipo admisión (sábado y domingo) y los
/// exámenes pasados, donde se ve la respuesta al instante.
class ExamenesPage extends StatefulWidget {
  final RepositorioExamenes repositorio;
  final ServicioExamenes servicio;
  final DateTime hoy;

  const ExamenesPage({
    super.key,
    required this.repositorio,
    required this.servicio,
    required this.hoy,
  });

  @override
  State<ExamenesPage> createState() => _ExamenesPageState();
}

class _ExamenesPageState extends State<ExamenesPage> {
  late Future<List<ExamenPasado>> _examenes = widget.repositorio.listar();
  TipoExamen _tipo = TipoExamen.ordinario;
  bool _tipoElegido = false;

  void _abrirPasado(ExamenPasado examen) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticaExamenPage(
          examen: examen,
          repositorio: widget.repositorio,
          servicio: widget.servicio,
        ),
      ),
    );
  }

  void _empezarSimulacro() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SimulacroPage(servicio: widget.servicio),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<ExamenPasado>>(
        future: _examenes,
        builder: (context, snapshot) {
          final examenes = snapshot.data ?? const <ExamenPasado>[];

          // Si no hay Ordinarios cargados, se abre en Exonerados.
          if (!_tipoElegido &&
              snapshot.hasData &&
              !examenes.any((e) => e.tipo == TipoExamen.ordinario) &&
              examenes.isNotEmpty) {
            _tipo = TipoExamen.exonerados;
          }

          final delTipo = examenes.where((e) => e.tipo == _tipo).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            children: [
              const Text(
                'Exámenes',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _TarjetaSimulacro(
                disponible: esDiaDeSimulacro(widget.hoy),
                alEmpezar: _empezarSimulacro,
              ),
              const SizedBox(height: 28),
              const Text(
                'EXÁMENES PASADOS · VES LA RESPUESTA AL INSTANTE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.apagado,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<TipoExamen>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: TipoExamen.ordinario,
                    label: Text('Ordinario'),
                  ),
                  ButtonSegment(
                    value: TipoExamen.exonerados,
                    label: Text('Exonerados'),
                  ),
                ],
                selected: {_tipo},
                onSelectionChanged: (valor) => setState(() {
                  _tipo = valor.first;
                  _tipoElegido = true;
                }),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError) ...[
                const Text('No se pudieron cargar los exámenes.'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _examenes = widget.repositorio.listar();
                    }),
                    child: const Text('Reintentar'),
                  ),
                ),
              ] else if (delTipo.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _tipo == TipoExamen.ordinario
                        ? 'Aún no hay exámenes Ordinario cargados.'
                        : 'Aún no hay exámenes Exonerados cargados.',
                    style: const TextStyle(color: ColoresApp.apagado),
                  ),
                )
              else
                for (final examen in delTipo)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      title: Text(
                        examen.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${examen.totalPreguntas} preguntas'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrirPasado(examen),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaSimulacro extends StatelessWidget {
  final bool disponible;
  final VoidCallback alEmpezar;

  const _TarjetaSimulacro({required this.disponible, required this.alEmpezar});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ColoresApp.ambar.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Sábado y domingo',
                style: TextStyle(
                  color: ColoresApp.ambar,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Examen tipo admisión',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Como el examen real: con tiempo y sin ver respuestas hasta '
              'el final · 20 preguntas · 40 min',
              style: TextStyle(color: ColoresApp.apagado, height: 1.4),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: disponible ? alEmpezar : null,
              child: Text(disponible ? 'Empezar' : 'Disponible el sábado'),
            ),
          ],
        ),
      ),
    );
  }
}
