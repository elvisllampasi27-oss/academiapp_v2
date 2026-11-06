import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/texto_con_latex.dart';
import '../../domain/entities/examen.dart';
import '../../domain/entities/simulacro.dart';
import '../../domain/repositories/servicio_examenes.dart';
import '../../../../core/presentation/imagen_figura.dart';
import 'ranking_semanal_page.dart';
import '../../../../core/presentation/animaciones.dart';

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

class _ResultadoSimulacroPageState extends State<ResultadoSimulacroPage> {
  bool _revisando = false;

  static String _tiempo(int segundos) {
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultado;
    final porId = {for (final p in widget.preguntas) p.id: p};

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ...enCascada([
            Text(
              widget.titulo,
              style: const TextStyle(color: ColoresApp.apagado),
            ),
            const SizedBox(height: 6),
            NumeroQueCuenta(
              '${r.correctas} de ${r.total} correctas',
              estilo: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${r.puntaje} % · tiempo usado ${_tiempo(r.tiempoUsadoSegundos)}',
              style: const TextStyle(color: ColoresApp.apagado),
            ),
            const SizedBox(height: 24),
            const Text(
              'Por área',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final s in r.porSeccion) _FilaSeccion(s),
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
          ]),
          // Fuera de la cascada: al tocar "Revisar", las preguntas entran
          // una tras otra (cada una con su clave).
          if (!_revisando)
            EntradaDifuminada(
              key: const ValueKey('revisar'),
              retraso: const Duration(milliseconds: 480),
              child: OutlinedButton(
                onPressed: () => setState(() => _revisando = true),
                child: const Text('Revisar mis respuestas'),
              ),
            )
          else
            for (final (i, d) in r.detalle.indexed)
              if (porId[d.preguntaId] case final pregunta?)
                FilaEntrante(
                  key: ValueKey(d.preguntaId),
                  indice: i,
                  child: _Revision(
                    numero: i + 1,
                    pregunta: pregunta,
                    detalle: d,
                  ),
                ),
        ],
      ),
    );
  }
}

class _FilaSeccion extends StatelessWidget {
  final ResultadoSeccion seccion;

  const _FilaSeccion(this.seccion);

  @override
  Widget build(BuildContext context) {
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
          BarraProgreso(
            valor: fraccion,
            minHeight: 6,
            radio: 3,
            color: fraccion < 0.5 ? ColoresApp.naranja : ColoresApp.celeste,
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
                IconoVeredicto(
                  correcta: detalle.esCorrecta,
                  tamano: 18,
                  retraso: const Duration(milliseconds: 350),
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
