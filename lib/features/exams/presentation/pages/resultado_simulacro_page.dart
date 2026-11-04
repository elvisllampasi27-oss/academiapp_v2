import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/confeti.dart';
import '../../../../core/presentation/texto_con_latex.dart';
import '../../domain/entities/examen.dart';
import '../../domain/entities/simulacro.dart';
import '../../domain/repositories/servicio_examenes.dart';
import '../../../../core/presentation/imagen_figura.dart';
import 'ranking_semanal_page.dart';

/// Resultado del examen semanal: total, por área, ranking y revisión.
class ResultadoSimulacroPage extends StatefulWidget {
  final ResultadoSimulacro resultado;
  final List<PreguntaExamen> preguntas;
  final String titulo;

  /// Para abrir el ranking (null = sin botón).
  final ServicioExamenes? servicio;

  const ResultadoSimulacroPage({
    super.key,
    required this.resultado,
    required this.preguntas,
    this.titulo = 'Examen semanal',
    this.servicio,
  });

  @override
  State<ResultadoSimulacroPage> createState() => _ResultadoSimulacroPageState();
}

class _ResultadoSimulacroPageState extends State<ResultadoSimulacroPage>
    with SingleTickerProviderStateMixin {
  bool _revisando = false;

  /// Entrada: el anillo se llena y las áreas aparecen una tras otra.
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _anillo = CurvedAnimation(
    parent: _entrada,
    curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
  );

  /// Su puesto en la semana (si se puede consultar) y confeti si es top 3.
  RankingSemanal? _ranking;

  @override
  void initState() {
    super.initState();
    widget.servicio
        ?.ranking()
        .then((r) {
          if (mounted) setState(() => _ranking = r);
        })
        .catchError((Object _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrada.isAnimating || _entrada.isCompleted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _entrada.value = 1;
    } else {
      _entrada.forward();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  Animation<double> _areaNumero(int i) => CurvedAnimation(
    parent: _entrada,
    curve: Interval(
      math.min(0.3 + 0.08 * i, 0.8),
      math.min(0.6 + 0.08 * i, 1.0),
      curve: Curves.easeOutCubic,
    ),
  );

  static String _tiempo(int segundos) {
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultado;
    final porId = {for (final p in widget.preguntas) p.id: p};

    final yo = _ranking?.yo;
    final podio = yo != null && yo.puesto <= 3;

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: Confeti(
        activo: podio,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              widget.titulo,
              style: const TextStyle(color: ColoresApp.apagado),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AnimatedBuilder(
                  animation: _anillo,
                  builder: (context, _) =>
                      _AnilloNota(valor: r.puntaje / 100 * _anillo.value),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.correctas} de ${r.total} correctas',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.puntaje} % · tiempo usado '
                        '${_tiempo(r.tiempoUsadoSegundos)}',
                        style: const TextStyle(color: ColoresApp.apagado),
                      ),
                      if (yo != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${switch (yo.puesto) {
                            1 => '🥇 ',
                            2 => '🥈 ',
                            3 => '🥉 ',
                            _ => '',
                          }}Puesto ${yo.puesto} de '
                          '${_ranking!.participantes} esta semana',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: podio ? ColoresApp.ambar : ColoresApp.texto,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Por área',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final (i, s) in r.porSeccion.indexed)
              _FilaSeccion(s, avance: _areaNumero(i)),
            const SizedBox(height: 20),
            if (widget.servicio case final servicio?) ...[
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RankingSemanalPage(servicio: servicio),
                  ),
                ),
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: const Text('Ver mi puesto en el ranking'),
              ),
              const SizedBox(height: 10),
            ],
            if (!_revisando)
              OutlinedButton(
                onPressed: () => setState(() => _revisando = true),
                child: const Text('Revisar mis respuestas'),
              )
            else
              for (final (i, d) in r.detalle.indexed)
                if (porId[d.preguntaId] case final pregunta?)
                  _Revision(numero: i + 1, pregunta: pregunta, detalle: d),
          ],
        ),
      ),
    );
  }
}

class _FilaSeccion extends StatelessWidget {
  final ResultadoSeccion seccion;

  /// 0 → 1: aparece desde abajo y su barra se llena.
  final Animation<double> avance;

  const _FilaSeccion(this.seccion, {required this.avance});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: avance,
      builder: (context, _) => Opacity(
        opacity: avance.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - avance.value)),
          child: _fila(avance.value),
        ),
      ),
    );
  }

  Widget _fila(double avance) {
    final fraccion = seccion.total == 0
        ? 0.0
        : seccion.correctas / seccion.total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(seccion.nombre)),
              Text(
                '${seccion.correctas} de ${seccion.total}',
                style: const TextStyle(color: ColoresApp.apagado),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraccion * avance,
              minHeight: 6,
              color: fraccion < 0.5 ? ColoresApp.naranja : ColoresApp.celeste,
            ),
          ),
        ],
      ),
    );
  }
}

class _Revision extends StatelessWidget {
  final int numero;
  final PreguntaExamen pregunta;
  final DetalleRespuesta detalle;

  const _Revision({
    required this.numero,
    required this.pregunta,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final elegida = detalle.opcionElegidaId;
    final textoDe = {for (final o in pregunta.opciones) o.id: o.texto};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  detalle.esCorrecta ? Icons.check_circle : Icons.cancel,
                  size: 18,
                  color: detalle.esCorrecta
                      ? ColoresApp.celeste
                      : ColoresApp.naranja,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pregunta $numero · ${pregunta.seccion}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextoConLatex(pregunta.enunciado),
            if (pregunta.imagen case final imagen?) ImagenFigura(imagen),
            const SizedBox(height: 8),
            Text(
              elegida == null
                  ? 'No respondiste.'
                  : 'Tu respuesta: ${pregunta.letraDe(elegida)}',
              style: const TextStyle(color: ColoresApp.apagado),
            ),
            if (elegida != null) TextoConLatex(textoDe[elegida] ?? ''),
            if (!detalle.esCorrecta) ...[
              const SizedBox(height: 6),
              Text(
                'Correcta: ${pregunta.letraDe(detalle.opcionCorrectaId)}',
                style: const TextStyle(color: ColoresApp.celeste),
              ),
              TextoConLatex(textoDe[detalle.opcionCorrectaId] ?? ''),
            ],
            if (detalle.solucion case final solucion?) ...[
              const SizedBox(height: 8),
              TextoConLatex(solucion),
            ],
            if (detalle.imagenSolucion case final imagen?) ImagenFigura(imagen),
          ],
        ),
      ),
    );
  }
}

/// Anillo con la nota en el centro (se llena con la animación de entrada).
class _AnilloNota extends StatelessWidget {
  /// 0 a 1.
  final double valor;

  const _AnilloNota({required this.valor});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 96,
      child: CustomPaint(
        painter: _PintorAnillo(valor),
        child: Center(
          child: Text(
            '${(valor * 100).round()}%',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _PintorAnillo extends CustomPainter {
  final double valor;

  _PintorAnillo(this.valor);

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 9.0;
    final rect = (Offset.zero & size).deflate(grosor / 2);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      pincel..color = const Color(0x1AFFFFFF),
    );
    if (valor > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * valor.clamp(0.0, 1.0),
        false,
        pincel..color = valor < 0.5 ? ColoresApp.naranja : ColoresApp.celeste,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorAnillo anterior) => anterior.valor != valor;
}
