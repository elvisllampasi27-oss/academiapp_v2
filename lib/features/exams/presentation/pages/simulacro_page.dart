import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/texto_con_latex.dart';
import '../../domain/entities/simulacro.dart';
import '../../domain/repositories/servicio_examenes.dart';
import '../widgets/imagen_examen.dart';
import '../widgets/opcion_examen.dart';
import 'resultado_simulacro_page.dart';

/// Examen tipo admisión: con tiempo y sin ver respuestas hasta el final.
/// Al acabarse el tiempo se envía solo.
class SimulacroPage extends StatefulWidget {
  final ServicioExamenes servicio;

  /// Reloj inyectable para pruebas.
  final DateTime Function() ahora;

  const SimulacroPage({
    super.key,
    required this.servicio,
    this.ahora = DateTime.now,
  });

  @override
  State<SimulacroPage> createState() => _SimulacroPageState();
}

class _SimulacroPageState extends State<SimulacroPage> {
  Simulacro? _simulacro;
  String? _errorInicio;

  final Map<String, String> _respuestas = {};
  int _indice = 0;
  bool _enviando = false;
  String? _errorEnvio;

  Timer? _reloj;
  Duration _restante = Duration.zero;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final simulacro = await widget.servicio.iniciarSimulacro();
      if (!mounted) return;
      setState(() {
        _simulacro = simulacro;
        _errorInicio = null;
      });
      _actualizarReloj();
      _reloj = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _actualizarReloj(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorInicio = e is ErrorExamen
            ? e.mensaje
            : 'No se pudo empezar el examen. Inténtalo de nuevo.';
      });
    }
  }

  void _actualizarReloj() {
    final simulacro = _simulacro;
    if (simulacro == null || !mounted) return;

    final restante = simulacro.vence.difference(widget.ahora());
    setState(() => _restante = restante.isNegative ? Duration.zero : restante);

    if (restante <= Duration.zero && !_enviando) {
      _reloj?.cancel();
      _enviar();
    }
  }

  Future<void> _enviar() async {
    final simulacro = _simulacro;
    if (simulacro == null || _enviando) return;

    setState(() {
      _enviando = true;
      _errorEnvio = null;
    });

    try {
      final resultado = await widget.servicio.enviarSimulacro(
        simulacroId: simulacro.id,
        respuestas: Map.of(_respuestas),
      );
      _reloj?.cancel();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultadoSimulacroPage(
            resultado: resultado,
            preguntas: simulacro.preguntas,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _errorEnvio = e is ErrorExamen
            ? e.mensaje
            : 'No se pudo enviar. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _confirmarTerminar() async {
    final total = _simulacro?.preguntas.length ?? 0;
    final sinResponder = total - _respuestas.length;

    final terminar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Terminar el examen?'),
        content: Text(switch (sinResponder) {
          0 => 'Respondiste todas las preguntas.',
          1 => 'Te falta 1 pregunta por responder.',
          _ => 'Te faltan $sinResponder preguntas por responder.',
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Seguir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Terminar'),
          ),
        ],
      ),
    );

    if (terminar == true) _enviar();
  }

  Future<void> _confirmarSalir() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Salir del examen?'),
        content: const Text(
          'El tiempo sigue corriendo. Si vuelves antes de que se acabe, '
          'continúas el mismo examen, pero tendrás que marcar de nuevo '
          'tus respuestas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Quedarme'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (salir == true && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  static String _formatoReloj(Duration d) {
    final minutos = d.inMinutes.toString().padLeft(2, '0');
    final segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  @override
  Widget build(BuildContext context) {
    final simulacro = _simulacro;

    return PopScope(
      canPop: simulacro == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_enviando) _confirmarSalir();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Examen tipo admisión'),
          actions: [
            if (simulacro != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    _formatoReloj(_restante),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _restante.inMinutes < 5
                          ? ColoresApp.naranja
                          : ColoresApp.texto,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: simulacro == null ? _cargando() : _examen(simulacro),
      ),
    );
  }

  Widget _cargando() {
    final error = _errorInicio;
    if (error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() => _errorInicio = null);
                _iniciar();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _examen(Simulacro simulacro) {
    final preguntas = simulacro.preguntas;
    final pregunta = preguntas[_indice];
    final esUltima = _indice == preguntas.length - 1;

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: preguntas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final respondida = _respuestas.containsKey(preguntas[i].id);
              final actual = i == _indice;

              return InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _indice = i),
                child: Container(
                  width: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: respondida ? ColoresApp.texto : ColoresApp.panel,
                    border: Border.all(
                      color: actual ? ColoresApp.ambar : ColoresApp.borde,
                      width: actual ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: respondida ? ColoresApp.fondo : ColoresApp.texto,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            key: ValueKey(pregunta.id),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'Pregunta ${_indice + 1} de ${preguntas.length} · ${pregunta.seccion}',
                style: const TextStyle(color: ColoresApp.apagado),
              ),
              const SizedBox(height: 12),
              TextoConLatex(
                pregunta.enunciado,
                estilo: const TextStyle(fontSize: 17),
              ),
              if (pregunta.imagen case final imagen?) ImagenExamen(imagen),
              const SizedBox(height: 12),
              for (final (i, opcion) in pregunta.opciones.indexed)
                OpcionExamenTile(
                  letra: String.fromCharCode(65 + i),
                  texto: opcion.texto,
                  estado: _respuestas[pregunta.id] == opcion.id
                      ? EstadoOpcion.elegida
                      : EstadoOpcion.normal,
                  alPresionar: _enviando
                      ? null
                      : () => setState(
                          () => _respuestas[pregunta.id] = opcion.id,
                        ),
                ),
              if (_errorEnvio case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error,
                    style: const TextStyle(color: ColoresApp.naranja),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: _indice == 0 || _enviando
                      ? null
                      : () => setState(() => _indice--),
                  child: const Text('Anterior'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _enviando
                      ? null
                      : esUltima
                      ? _confirmarTerminar
                      : () => setState(() => _indice++),
                  child: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(esUltima ? 'Terminar' : 'Siguiente'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
