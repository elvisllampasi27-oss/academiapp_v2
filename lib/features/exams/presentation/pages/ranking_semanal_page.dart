import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/esqueleto.dart';
import '../../domain/entities/simulacro.dart';
import '../../domain/repositories/servicio_examenes.dart';

/// Top 10 del último examen semanal que diste y tu puesto.
class RankingSemanalPage extends StatefulWidget {
  final ServicioExamenes servicio;

  const RankingSemanalPage({super.key, required this.servicio});

  @override
  State<RankingSemanalPage> createState() => _RankingSemanalPageState();
}

class _RankingSemanalPageState extends State<RankingSemanalPage> {
  late Future<RankingSemanal?> _ranking = widget.servicio.ranking();

  static String _tiempo(int segundos) =>
      '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking semanal')),
      body: FutureBuilder<RankingSemanal?>(
        future: _ranking,
        builder: (context, s) {
          if (s.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.error is ErrorExamen
                        ? (s.error as ErrorExamen).mensaje
                        : 'No se pudo cargar el ranking.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _ranking = widget.servicio.ranking();
                    }),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (s.connectionState != ConnectionState.done) {
            return const EsqueletoLista(tarjetas: 5);
          }
          final ranking = s.data;
          if (ranking == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Cuando des tu primer examen semanal, aquí verás tu puesto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresApp.apagado),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                ranking.titulo,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ranking.participantes} '
                '${ranking.participantes == 1 ? 'estudiante lo dio' : 'estudiantes lo dieron'}',
                style: const TextStyle(color: ColoresApp.apagado),
              ),
              if (ranking.yo case final yo?) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ColoresApp.ambar.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${yo.puesto}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.ambar,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Tu puesto · ${yo.puntaje} % · '
                          '${yo.correctas} de ${yo.total} en '
                          '${_tiempo(yo.tiempoUsadoSegundos)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'TOP 10',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.apagado,
                ),
              ),
              const SizedBox(height: 8),
              for (final p in ranking.top) _FilaPuesto(p, _tiempo),
            ],
          );
        },
      ),
    );
  }
}

class _FilaPuesto extends StatelessWidget {
  final PuestoRanking p;
  final String Function(int) tiempo;

  const _FilaPuesto(this.p, this.tiempo);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: p.soyYo ? ColoresApp.ambar.withValues(alpha: 0.12) : null,
      child: ListTile(
        leading: SizedBox(
          width: 36,
          child: Center(
            child: Text(
              switch (p.puesto) {
                1 => '🥇',
                2 => '🥈',
                3 => '🥉',
                _ => '${p.puesto}',
              },
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        title: Text(
          p.soyYo ? '${p.nombre} (tú)' : p.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${p.correctas} de ${p.total} · ${tiempo(p.tiempoUsadoSegundos)}',
        ),
        trailing: Text(
          '${p.puntaje} %',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
