import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/correccion_intento.dart';
import '../../domain/entities/evaluacion.dart';
import '../../domain/entities/pregunta_presentada.dart';
import '../../domain/services/practica_tema_service.dart';
import '../../../../core/presentation/texto_con_latex.dart';
import '../../../../core/presentation/imagen_figura.dart';
import '../../../../core/presentation/animaciones.dart';

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

  /// Mismo id en los reintentos del envío; uno nuevo al repetir la práctica.
  String _intentoId = nuevoIdIntento();
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
        intentoId: _intentoId,
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
      _intentoId = nuevoIdIntento();
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
        // La barra avanza suave hasta la pregunta actual.
        TweenAnimationBuilder<double>(
          tween: Tween(end: (_indice + 1) / preguntas.length),
          duration: sinAnimaciones(context)
              ? Duration.zero
              : const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, avance, _) =>
              LinearProgressIndicator(value: avance),
        ),
        Expanded(
          // Con la clave, cada pregunta nueva entra desde arriba con su
          // animación (y la lista vuelve al inicio).
          child: ListView(
            key: ValueKey(pregunta.id),
            padding: const EdgeInsets.all(24),
            children: [
              EntradaDifuminada(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    if (pregunta.imagen case final imagen?)
                      ImagenFigura(imagen),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              for (final (i, opcion) in pregunta.opciones.indexed)
                FilaEntrante(
                  indice: i,
                  child: _TarjetaOpcion(
                    letra: String.fromCharCode(65 + i),
                    texto: opcion.texto,
                    seleccionada: elegida == opcion.id,
                    alPresionar: _enviando
                        ? null
                        : () => setState(
                            () => _elegidas[pregunta.id] = opcion.id,
                          ),
                  ),
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

/// Opción de respuesta: al elegirla se hunde un poco y vuelve (como un
/// botón físico) y sus colores cambian suave, sin saltos.
class _TarjetaOpcion extends StatefulWidget {
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
  State<_TarjetaOpcion> createState() => _TarjetaOpcionState();
}

class _TarjetaOpcionState extends State<_TarjetaOpcion>
    with SingleTickerProviderStateMixin {
  static const _duracion = Duration(milliseconds: 220);

  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: _duracion,
    value: 1,
  );
  late final Animation<double> _escala = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 0.97), weight: 40),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.97,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 60,
    ),
  ]).animate(_pulso);

  @override
  void didUpdateWidget(_TarjetaOpcion anterior) {
    super.didUpdateWidget(anterior);
    if (widget.seleccionada && !anterior.seleccionada) {
      if (!sinAnimaciones(context)) _pulso.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final elegida = widget.seleccionada;
    final duracion = sinAnimaciones(context) ? Duration.zero : _duracion;
    final fondoNormal =
        Theme.of(context).cardTheme.color ?? colores.surfaceContainerLow;

    return ScaleTransition(
      scale: _escala,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(
          end: elegida ? colores.primaryContainer : fondoNormal,
        ),
        duration: duracion,
        builder: (context, fondo, hijo) => Card(color: fondo, child: hijo),
        child: ListTile(
          leading: AnimatedContainer(
            duration: duracion,
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: elegida ? colores.primary : colores.secondaryContainer,
            ),
            child: AnimatedDefaultTextStyle(
              duration: duracion,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: elegida
                    ? colores.onPrimary
                    : colores.onSecondaryContainer,
              ),
              child: Text(widget.letra),
            ),
          ),
          title: TextoConLatex(widget.texto),
          onTap: widget.alPresionar,
        ),
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
        EntradaDifuminada(
          child: Row(
            children: [
              _AnilloPuntaje(puntaje: resultado.puntaje),
              const SizedBox(width: 20),
              Expanded(
                child: NumeroQueCuenta(
                  '${resultado.respuestasCorrectas} de '
                  '${resultado.totalPreguntas} correctas',
                  estilo: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final (i, item) in correccion.detalle.indexed)
          if (porPregunta[item.preguntaId] case final pregunta?)
            FilaEntrante(
              indice: i,
              child: _TarjetaCorreccion(
                numero: i + 1,
                pregunta: pregunta,
                item: item,
                retrasoIcono: Duration(
                  milliseconds: 450 + 45 * math.min(i, 12),
                ),
              ),
            ),
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
  final Duration retrasoIcono;

  const _TarjetaCorreccion({
    required this.numero,
    required this.pregunta,
    required this.item,
    required this.retrasoIcono,
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
                _IconoVeredicto(
                  correcta: item.esCorrecta,
                  color: colorEstado,
                  retraso: retrasoIcono,
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
            if (pregunta.imagen case final imagen?) ImagenFigura(imagen),
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

/// El puntaje en un anillo que se llena mientras el porcentaje cuenta.
class _AnilloPuntaje extends StatelessWidget {
  final double puntaje;

  const _AnilloPuntaje({required this.puntaje});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final fin = (puntaje / 100).clamp(0, 1).toDouble();

    return SizedBox.square(
      dimension: 76,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fin),
            duration: sinAnimaciones(context)
                ? Duration.zero
                : const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, valor, _) => CircularProgressIndicator(
              value: valor,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: colores.surfaceContainerHighest,
            ),
          ),
          Center(
            child: NumeroQueCuenta(
              '${puntaje.round()} %',
              estilo: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// El ✓ aparece con un rebote; la ✗ aparece y se sacude una vez.
/// Corre una sola vez y queda quieto (sin efectos encima).
class _IconoVeredicto extends StatefulWidget {
  final bool correcta;
  final Color color;
  final Duration retraso;

  const _IconoVeredicto({
    required this.correcta,
    required this.color,
    required this.retraso,
  });

  @override
  State<_IconoVeredicto> createState() => _IconoVeredictoState();
}

class _IconoVeredictoState extends State<_IconoVeredicto>
    with SingleTickerProviderStateMixin {
  static const _duracion = Duration(milliseconds: 700);

  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: widget.retraso + _duracion,
  );

  /// Parte del tiempo total en que empieza a moverse.
  late final double _inicio =
      widget.retraso.inMicroseconds /
      (widget.retraso + _duracion).inMicroseconds;

  late final Animation<double> _aparece = CurvedAnimation(
    parent: _control,
    curve: Interval(
      _inicio,
      _inicio + (1 - _inicio) * 0.5,
      curve: Curves.easeOutBack,
    ),
  );
  late final Animation<double> _sacude = CurvedAnimation(
    parent: _control,
    curve: Interval(_inicio + (1 - _inicio) * 0.5, 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_control.isAnimating || _control.isCompleted) return;
    if (sinAnimaciones(context)) {
      _control.value = 1;
    } else {
      _control.forward();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _control,
      child: Icon(
        widget.correcta ? Icons.check_circle : Icons.cancel,
        color: widget.color,
      ),
      builder: (context, icono) {
        final s = _sacude.value;
        // Tres vaivenes que se apagan; en 0 y en 1 queda en su lugar.
        final dx = widget.correcta
            ? 0.0
            : math.sin(s * math.pi * 6) * 4 * (1 - s);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: _aparece.value.clamp(0, 1.3).toDouble(),
            child: icono,
          ),
        );
      },
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
