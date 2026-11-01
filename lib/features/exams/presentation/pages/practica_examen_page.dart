import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/texto_con_latex.dart';
import '../../domain/entities/examen.dart';
import '../../domain/repositories/repositorio_examenes.dart';
import '../../domain/repositories/servicio_examenes.dart';
import '../widgets/imagen_examen.dart';
import '../widgets/opcion_examen.dart';

/// Examen pasado en modo práctica: respondes y ves al instante si acertaste,
/// la correcta y la solución.
class PracticaExamenPage extends StatefulWidget {
  final ExamenPasado examen;
  final RepositorioExamenes repositorio;
  final ServicioExamenes servicio;

  const PracticaExamenPage({
    super.key,
    required this.examen,
    required this.repositorio,
    required this.servicio,
  });

  @override
  State<PracticaExamenPage> createState() => _PracticaExamenPageState();
}

class _PracticaExamenPageState extends State<PracticaExamenPage> {
  late Future<List<PreguntaExamen>> _preguntas = widget.repositorio.preguntas(
    widget.examen.id,
  );

  int _indice = 0;
  int _aciertos = 0;
  bool _terminado = false;

  String? _elegida;
  RevisionPregunta? _revision;
  bool _revisando = false;
  String? _error;

  Future<void> _responder(PreguntaExamen pregunta, String opcionId) async {
    setState(() {
      _elegida = opcionId;
      _revisando = true;
      _error = null;
    });

    try {
      final revision = await widget.servicio.revisar(
        preguntaId: pregunta.id,
        opcionId: opcionId,
      );
      if (!mounted) return;
      setState(() {
        _revision = revision;
        if (revision.esCorrecta) _aciertos++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _elegida = null;
        _error = e is ErrorExamen
            ? e.mensaje
            : 'Ocurrió un error. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _revisando = false);
    }
  }

  void _siguiente(int total) {
    setState(() {
      if (_indice + 1 >= total) {
        _terminado = true;
      } else {
        _indice++;
      }
      _elegida = null;
      _revision = null;
      _error = null;
    });
  }

  EstadoOpcion _estadoDe(OpcionExamen opcion) {
    final revision = _revision;
    if (revision == null) {
      return opcion.id == _elegida ? EstadoOpcion.elegida : EstadoOpcion.normal;
    }
    if (opcion.id == revision.opcionCorrectaId) return EstadoOpcion.correcta;
    if (opcion.id == _elegida) return EstadoOpcion.incorrecta;
    return EstadoOpcion.normal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.examen.titulo)),
      body: FutureBuilder<List<PreguntaExamen>>(
        future: _preguntas,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Mensaje(
              texto: 'No se pudieron cargar las preguntas.',
              boton: 'Reintentar',
              alPresionar: () => setState(() {
                _preguntas = widget.repositorio.preguntas(widget.examen.id);
              }),
            );
          }

          final preguntas = snapshot.data!;
          if (preguntas.isEmpty) {
            return const _Mensaje(texto: 'Este examen no tiene preguntas.');
          }
          if (_terminado) {
            return _Mensaje(
              texto: 'Acertaste $_aciertos de ${preguntas.length}.',
              boton: 'Volver a exámenes',
              alPresionar: () => Navigator.of(context).pop(),
            );
          }

          return _vistaPregunta(preguntas);
        },
      ),
    );
  }

  Widget _vistaPregunta(List<PreguntaExamen> preguntas) {
    final pregunta = preguntas[_indice];
    final revision = _revision;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_indice + 1) / preguntas.length,
          minHeight: 3,
          color: ColoresApp.ambar,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                '${_indice + 1} de ${preguntas.length} · ${pregunta.seccion}',
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
                  estado: _estadoDe(opcion),
                  alPresionar: revision != null || _revisando
                      ? null
                      : () => _responder(pregunta, opcion.id),
                ),
              if (_revisando)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error,
                    style: const TextStyle(color: ColoresApp.naranja),
                  ),
                ),
              if (revision != null) ...[
                const SizedBox(height: 16),
                Text(
                  revision.esCorrecta
                      ? '¡Correcto! Es la ${pregunta.letraDe(revision.opcionCorrectaId)}'
                      : 'La correcta es la ${pregunta.letraDe(revision.opcionCorrectaId)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: revision.esCorrecta
                        ? ColoresApp.celeste
                        : ColoresApp.naranja,
                  ),
                ),
                if (revision.solucion case final solucion?) ...[
                  const SizedBox(height: 8),
                  TextoConLatex(solucion),
                ],
                if (revision.imagenSolucion case final imagen?)
                  ImagenExamen(imagen),
              ],
            ],
          ),
        ),
        if (revision != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _siguiente(preguntas.length),
                  child: Text(
                    _indice + 1 >= preguntas.length
                        ? 'Ver resultado'
                        : 'Siguiente pregunta',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  final String texto;
  final String? boton;
  final VoidCallback? alPresionar;

  const _Mensaje({required this.texto, this.boton, this.alPresionar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            if (boton != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: alPresionar, child: Text(boton!)),
            ],
          ],
        ),
      ),
    );
  }
}
