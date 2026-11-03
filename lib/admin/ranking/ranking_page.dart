import 'package:flutter/material.dart';

import '../estudiantes/modelo_estudiantes.dart';
import '../examenes/modelo_examen_admin.dart';
import '../examenes/repositorio_examenes_admin.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'ranking_admin.dart';

/// Puestos de cada examen semanal (el mismo orden que ve el estudiante).
class RankingPage extends StatefulWidget {
  final RepositorioExamenesAdmin semanales;
  final RepositorioRankingAdmin ranking;
  final ValueChanged<String> onAbrirEstudiante;

  const RankingPage({
    super.key,
    required this.semanales,
    required this.ranking,
    required this.onAbrirEstudiante,
  });

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  late final Future<List<ExamenAdmin>> _examenes = widget.semanales
      .examenes()
      .then((l) => l.where((e) => e.publicado).toList());
  String? _examenId;
  Future<List<ResultadoSemanal>>? _resultados;

  void _elegir(String id) {
    setState(() {
      _examenId = id;
      _resultados = widget.ranking.resultados(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel<List<ExamenAdmin>>(
      futuro: _examenes,
      onReintentar: () => setState(() {}),
      builder: (context, examenes) {
        final p = PaletaPanel.de(context);
        if (_examenId == null && examenes.isNotEmpty) {
          // Por defecto, el último examen semanal publicado.
          _examenId = examenes.last.id;
          _resultados = widget.ranking.resultados(examenes.last.id);
        }
        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Ranking semanal',
              subtitulo:
                  'Puestos por examen semanal: más nota primero y, si '
                  'empatan, menos tiempo. En la app cada estudiante ve el '
                  'top 10 y su propio puesto.',
              acciones: [
                if (_examenId case final id?)
                  OutlinedButton.icon(
                    onPressed: () => _elegir(id),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar'),
                  ),
              ],
            ),
            if (examenes.isEmpty)
              TarjetaPanel(
                child: Text(
                  'Todavía no hay exámenes semanales publicados.',
                  style: TextStyle(color: p.apagado),
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in examenes)
                    ChoiceChip(
                      label: Text(e.titulo),
                      selected: e.id == _examenId,
                      onSelected: (_) => _elegir(e.id),
                    ),
                ],
              ),
              FuturoPanel<List<ResultadoSemanal>>(
                key: ValueKey(_examenId),
                futuro: _resultados!,
                onReintentar: () => _elegir(_examenId!),
                builder: (context, resultados) => _tabla(resultados),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _tabla(List<ResultadoSemanal> resultados) {
    final p = PaletaPanel.de(context);
    final filas = ordenarRanking(resultados);
    final promedio = resultados.isEmpty
        ? 0
        : (resultados.fold<int>(0, (s, r) => s + r.puntaje) / resultados.length)
              .round();
    const columnas = [
      ('PUESTO', 1),
      ('ESTUDIANTE', 4),
      ('NOTA', 1),
      ('CORRECTAS', 2),
      ('TIEMPO', 1),
      ('TERMINÓ', 2),
    ];

    Widget fila(
      List<Widget> celdas, {
      bool cabecera = false,
      VoidCallback? onTap,
    }) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cabecera ? PaletaPanel.bordeFuerte : PaletaPanel.linea,
            ),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < celdas.length; i++)
              Expanded(flex: columnas[i].$2, child: celdas[i]),
          ],
        ),
      ),
    );

    return ColumnaPanel(
      children: [
        RejillaPanel(
          anchoMinimo: 220,
          children: [
            IndicadorPanel(
              etiqueta: 'Lo dieron',
              valor: '${resultados.length}',
              nota: 'estudiantes',
            ),
            IndicadorPanel(
              etiqueta: 'Nota promedio',
              valor: '$promedio %',
              anillo: promedio / 100,
            ),
            IndicadorPanel(
              etiqueta: 'Mejor nota',
              valor: filas.isEmpty ? '—' : '${filas.first.$2.puntaje} %',
              nota: filas.isEmpty ? null : filas.first.$2.nombre,
            ),
          ],
        ),
        TarjetaPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              fila(cabecera: true, [
                for (final (t, _) in columnas)
                  Text(
                    t,
                    maxLines: 1,
                    style: TextStyle(
                      color: p.tenue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
              ]),
              if (filas.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'Nadie lo ha dado todavía.',
                    style: TextStyle(color: p.apagado),
                  ),
                ),
              for (final (puesto, r) in filas)
                fila(onTap: () => widget.onAbrirEstudiante(r.uid), [
                  Text(switch (puesto) {
                    1 => '🥇',
                    2 => '🥈',
                    3 => '🥉',
                    _ => '$puesto',
                  }, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Row(
                    children: [
                      AvatarIniciales(r.nombre),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.nombre.isEmpty ? r.uid : r.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${r.puntaje} %',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: r.puntaje >= 60 ? p.secundario : p.texto,
                    ),
                  ),
                  Text(
                    '${r.correctas} de ${r.total}',
                    style: TextStyle(color: p.apagado),
                  ),
                  Text(
                    duracionBreve(r.segundos),
                    style: TextStyle(color: p.apagado),
                  ),
                  Text(
                    fechaBreve(r.terminado),
                    style: TextStyle(color: p.apagado),
                  ),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}
