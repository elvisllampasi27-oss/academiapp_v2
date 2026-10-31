import 'package:flutter/material.dart';

import '../../domain/entities/correccion_intento.dart';
import '../../domain/entities/evaluacion.dart';
import '../../domain/entities/pregunta_presentada.dart';
import '../../domain/services/practica_tema_service.dart';
import '../widgets/texto_con_latex.dart';

/// Resolver una práctica: una pregunta a la vez y, al final, la corrección
/// que devuelve el servidor (con la respuesta correcta y la explicación).
class PracticaPage extends StatefulWidget {
  final PracticaTemaService service;
  final Evaluacion evaluacion;
  final String titulo;
  final String subtitulo;

  const PracticaPage({
    super.key,
    required this.service,
    required this.evaluacion,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  State<PracticaPage> createState() => _PracticaPageState();
}

class _PracticaPageState extends State<PracticaPage> {
  late Future<List<PreguntaPresentada>> _preguntas;

  final Map<String, String> _elegidas = {};
  final Map<String, int> _tiemposMs = {};
  final Stopwatch _cronometro = Stopwatch();

  int _indice = 0;
  bool _enviando = false;
  String? _error;
  CorreccionIntento? _correccion;

  @override
  void initState() {
    super.initState();
    _preguntas = _cargar();
  }

  Future<List<PreguntaPresentada>> _cargar() async {
    final preguntas = await widget.service.preguntas(widget.evaluacion.id);
    _cronometro
      ..reset()
      ..start();
    return preguntas;
  }

  void _registrarTiempo(PreguntaPresentada pregunta) {
    _tiemposMs[pregunta.id] =
        (_tiemposMs[pregunta.id] ?? 0) + _cronometro.elapsedMilliseconds;
    _cronometro
      ..reset()
      ..start();
  }

  void _irA(List<PreguntaPresentada> preguntas, int nuevoIndice) {
    _registrarTiempo(preguntas[_indice]);
    setState(() => _indice = nuevoIndice);
  }

  Future<void> _enviar(List<PreguntaPresentada> preguntas) async {
    _registrarTiempo(preguntas[_indice]);
    _cronometro.stop();

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final correccion = await widget.service.enviar(
        evaluacionId: widget.evaluacion.id,
        respuestas: Map.of(_elegidas),
        tiemposMs: Map.of(_tiemposMs),
      );

      if (!mounted) return;

      setState(() => _correccion = correccion);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error is StateError
            ? error.message
            : 'No se pudo enviar. Revisa tu conexión e inténtalo de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  void _reiniciar() {
    setState(() {
      _elegidas.clear();
      _tiemposMs.clear();
      _indice = 0;
      _correccion = null;
      _error = null;
      _cronometro
        ..reset()
        ..start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: FutureBuilder<List<PreguntaPresentada>>(
        future: _preguntas,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _Mensaje(
              texto: 'No se pudieron cargar las preguntas.',
              accion: 'Reintentar',
              alPresionar: () {
                setState(() {
                  _preguntas = _cargar();
                });
              },
            );
          }

          final preguntas = snapshot.data!;

          if (preguntas.isEmpty) {
            return const _Mensaje(
              texto: 'Esta práctica todavía no tiene preguntas.',
            );
          }

          final correccion = _correccion;

          return correccion == null
              ? _vistaPregunta(preguntas)
              : _VistaResultado(
                  preguntas: preguntas,
                  correccion: correccion,
                  alReintentar: _reiniciar,
                );
        },
      ),
    );
  }

  Widget _vistaPregunta(List<PreguntaPresentada> preguntas) {
    final pregunta = preguntas[_indice];
    final elegida = _elegidas[pregunta.id];
    final esUltima = _indice == preguntas.length - 1;

    return Column(
      children: [
        LinearProgressIndicator(value: (_indice + 1) / preguntas.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Pregunta ${_indice + 1} de ${preguntas.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              TextoConLatex(
                pregunta.enunciado,
                estilo: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              for (final (i, opcion) in pregunta.opciones.indexed)
                _TarjetaOpcion(
                  letra: String.fromCharCode(65 + i),
                  texto: opcion.texto,
                  seleccionada: elegida == opcion.id,
                  alPresionar: _enviando
                      ? null
                      : () => setState(() => _elegidas[pregunta.id] = opcion.id),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                if (_indice > 0)
                  OutlinedButton(
                    onPressed: _enviando
                        ? null
                        : () => _irA(preguntas, _indice - 1),
                    child: const Text('Anterior'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: elegida == null || _enviando
                      ? null
                      : esUltima
                      ? () => _enviar(preguntas)
                      : () => _irA(preguntas, _indice + 1),
                  child: _enviando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(esUltima ? 'Enviar' : 'Siguiente'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaOpcion extends StatelessWidget {
  final String letra;
  final String texto;
  final bool seleccionada;
  final VoidCallback? alPresionar;

  const _TarjetaOpcion({
    required this.letra,
    required this.texto,
    required this.seleccionada,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Card(
      color: seleccionada ? colores.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: seleccionada ? colores.primary : null,
          foregroundColor: seleccionada ? colores.onPrimary : null,
          child: Text(letra),
        ),
        title: TextoConLatex(texto),
        onTap: alPresionar,
      ),
    );
  }
}

class _VistaResultado extends StatelessWidget {
  final List<PreguntaPresentada> preguntas;
  final CorreccionIntento correccion;
  final VoidCallback alReintentar;

  const _VistaResultado({
    required this.preguntas,
    required this.correccion,
    required this.alReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final resultado = correccion.resultado;
    final porPregunta = {for (final p in preguntas) p.id: p};

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '${resultado.respuestasCorrectas} de ${resultado.totalPreguntas} correctas',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('${resultado.puntaje.round()} %'),
        const SizedBox(height: 24),
        for (final (i, item) in correccion.detalle.indexed)
          if (porPregunta[item.preguntaId] case final pregunta?)
            _TarjetaCorreccion(numero: i + 1, pregunta: pregunta, item: item),
        const SizedBox(height: 16),
        // OverflowBar: en línea si caben; uno debajo del otro si no.
        OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          spacing: 12,
          overflowSpacing: 8,
          overflowAlignment: OverflowBarAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver al tema'),
            ),
            FilledButton(
              onPressed: alReintentar,
              child: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaCorreccion extends StatelessWidget {
  final int numero;
  final PreguntaPresentada pregunta;
  final CorreccionPregunta item;

  const _TarjetaCorreccion({
    required this.numero,
    required this.pregunta,
    required this.item,
  });

  String _textoOpcion(String? id) {
    for (final opcion in pregunta.opciones) {
      if (opcion.id == id) return opcion.texto;
    }
    return 'Sin responder';
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final colorEstado = item.esCorrecta ? Colors.green.shade700 : colores.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.esCorrecta ? Icons.check_circle : Icons.cancel,
                  color: colorEstado,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pregunta $numero',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextoConLatex(pregunta.enunciado),
            const SizedBox(height: 8),
            if (!item.esCorrecta) ...[
              Text('Tu respuesta:', style: TextStyle(color: colorEstado)),
              TextoConLatex(_textoOpcion(item.opcionElegidaId)),
              const SizedBox(height: 4),
            ],
            const Text(
              'Respuesta correcta:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextoConLatex(_textoOpcion(item.opcionCorrectaId)),
            if (item.explicacion != null) ...[
              const SizedBox(height: 8),
              TextoConLatex(
                item.explicacion!,
                estilo: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final String texto;
  final String? accion;
  final VoidCallback? alPresionar;

  const _Mensaje({required this.texto, this.accion, this.alPresionar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texto, textAlign: TextAlign.center),
            if (accion != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: alPresionar, child: Text(accion!)),
            ],
          ],
        ),
      ),
    );
  }
}
