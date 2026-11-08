import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/formato_fecha.dart';
import '../../domain/entities/examen.dart';
import '../../domain/entities/simulacro.dart';
import '../../domain/repositories/repositorio_examenes.dart';
import '../../domain/repositories/servicio_examenes.dart';
import 'practica_examen_page.dart';
import 'ranking_semanal_page.dart';
import 'simulacro_page.dart';
import '../../../../core/presentation/animaciones.dart';
import '../../../../core/presentation/carga_puma.dart';

/// Pestaña Exámenes: el examen semanal (sábado y domingo) y los
/// exámenes pasados, donde se ve la respuesta al instante.
class ExamenesPage extends StatefulWidget {
  final RepositorioExamenes repositorio;
  final ServicioExamenes servicio;
  final DateTime hoy;
  final ReportarPreguntaExamen? onReportar;

  const ExamenesPage({
    super.key,
    required this.repositorio,
    required this.servicio,
    required this.hoy,
    this.onReportar,
  });

  @override
  State<ExamenesPage> createState() => _ExamenesPageState();
}

class _ExamenesPageState extends State<ExamenesPage> {
  late Future<List<ExamenPasado>> _examenes = widget.repositorio.listar();
  late Future<EstadoExamenSemanal> _estado = widget.servicio.estadoSemanal();
  TipoExamen _tipo = TipoExamen.ordinario;
  bool _tipoElegido = false;

  void _abrirPasado(ExamenPasado examen) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticaExamenPage(
          examen: examen,
          repositorio: widget.repositorio,
          servicio: widget.servicio,
          onReportar: widget.onReportar,
        ),
      ),
    );
  }

  Future<void> _empezarSimulacro(EstadoExamenSemanal estado) async {
    if (estado.intento == EstadoIntento.pendiente && !await _confirmar()) {
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SimulacroPage(servicio: widget.servicio),
      ),
    );
    // Al volver, la tarjeta muestra "Ya lo diste".
    if (mounted) {
      setState(() {
        _estado = widget.servicio.estadoSemanal();
      });
    }
  }

  Future<bool> _confirmar() async {
    final empezar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Empezar el examen semanal?'),
        content: const Text(
          'Tienes un solo intento y corre el tiempo desde que empiezas. '
          'Tu nota entra al ranking de la semana.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Todavía no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Empezar'),
          ),
        ],
      ),
    );
    return empezar == true;
  }

  void _verRanking() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RankingSemanalPage(servicio: widget.servicio),
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
            children: enCascada([
              const Text(
                'Exámenes',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              FutureBuilder<EstadoExamenSemanal>(
                future: _estado,
                builder: (context, s) => _TarjetaSimulacro(
                  estado: s.data,
                  alEmpezar: _empezarSimulacro,
                  alVerRanking: _verRanking,
                ),
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
                  child: Center(child: CargaPuma.compacta()),
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
                    key: ValueKey('examen-${examen.id}'),
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
            ]),
          );
        },
      ),
    );
  }
}

class _TarjetaSimulacro extends StatelessWidget {
  /// null mientras se consulta.
  final EstadoExamenSemanal? estado;
  final ValueChanged<EstadoExamenSemanal> alEmpezar;
  final VoidCallback alVerRanking;

  const _TarjetaSimulacro({
    required this.estado,
    required this.alEmpezar,
    required this.alVerRanking,
  });

  @override
  Widget build(BuildContext context) {
    final e = estado;
    final hasta = e?.cierra == null
        ? null
        : fechaCorta(e!.cierra!.subtract(const Duration(minutes: 1)))
              .toLowerCase();
    final (etiqueta, texto, boton) = switch (e) {
      null => ('Examen semanal', 'Revisando tu examen…', 'Empezar'),
      EstadoExamenSemanal(semana: 0) => (
        'Se abre el sábado',
        'Cada sábado se abre el examen de la semana que completaste, con '
            'esos temas. Queda abierto hasta el sábado siguiente.',
        'Disponible el sábado',
      ),
      EstadoExamenSemanal(publicado: false, :final semana) => (
        'Semana $semana',
        'El examen de tu semana $semana todavía no está listo. Vuelve '
            'más tarde.',
        'Todavía no está listo',
      ),
      EstadoExamenSemanal(
        intento: EstadoIntento.completado,
        :final semana,
        :final puntaje,
      ) =>
        (
          'Semana $semana',
          'Ya lo diste${puntaje == null ? '' : ': $puntaje %'}. Mira tu '
              'puesto en el ranking.',
          'Ya lo diste',
        ),
      EstadoExamenSemanal(requierePremium: true, :final semana) => (
        'Semana $semana',
        'El examen semanal es para Premium. Hazte Premium desde tu Perfil.',
        'Solo Premium',
      ),
      final EstadoExamenSemanal actual => (
        'Semana ${actual.semana}',
        'Con los temas de tu semana ${actual.semana} · ${actual.totalPreguntas} '
            'preguntas · un solo intento y con tiempo. Cuenta para el '
            'ranking.${hasta == null ? '' : ' Tienes hasta el $hasta.'}',
        actual.intento == EstadoIntento.enCurso ? 'Continuar' : 'Empezar',
      ),
    };

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
              child: Text(
                etiqueta,
                style: const TextStyle(
                  color: ColoresApp.ambar,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Examen semanal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              style: const TextStyle(color: ColoresApp.apagado, height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: e != null && e.disponible
                      ? () => alEmpezar(e)
                      : null,
                  child: Text(boton),
                ),
                OutlinedButton.icon(
                  onPressed: alVerRanking,
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: const Text('Ranking'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
