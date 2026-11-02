import 'package:flutter/material.dart';

import '../../core/presentation/texto_con_latex.dart';
import '../../features/academic/domain/entities/curso.dart';
import '../../features/academic/domain/entities/tema.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'modelo_contenido.dart';
import 'repositorio_contenido_admin.dart';

/// Preguntas de un nivel del quiz de un tema. Se pueden escribir a mano o
/// pedir borradores a la IA; nada se publica sin revisarlo aquí.
class EditorQuizPage extends StatefulWidget {
  final String versionId;
  final Tema tema;
  final Curso curso;
  final NivelQuiz nivel;
  final RepositorioContenidoAdmin repositorio;
  final GeneradorQuiz generador;

  /// El estado del quiz si se guardó; null si se salió sin guardar.
  final ValueChanged<QuizTema?> onVolver;

  const EditorQuizPage({
    super.key,
    required this.versionId,
    required this.tema,
    required this.curso,
    required this.nivel,
    required this.repositorio,
    required this.generador,
    required this.onVolver,
  });

  @override
  State<EditorQuizPage> createState() => _EditorQuizPageState();
}

class _Editable {
  final TextEditingController enunciado;
  final List<TextEditingController> opciones;
  final TextEditingController explicacion;
  int correcta;
  final bool deIa;

  _Editable(PreguntaPractica p, {this.deIa = false})
    : enunciado = TextEditingController(text: p.enunciado),
      opciones = [for (final o in p.opciones) TextEditingController(text: o)],
      explicacion = TextEditingController(text: p.explicacion),
      correcta = p.correcta;

  _Editable.vacia()
    : this(
        const PreguntaPractica(
          enunciado: '',
          opciones: ['', '', '', '', ''],
          correcta: -1,
        ),
      );

  PreguntaPractica get valor => PreguntaPractica(
    enunciado: enunciado.text,
    opciones: [for (final o in opciones) o.text],
    correcta: correcta,
    explicacion: explicacion.text,
  );

  void dispose() {
    for (final c in [enunciado, explicacion, ...opciones]) {
      c.dispose();
    }
  }
}

class _EditorQuizPageState extends State<EditorQuizPage> {
  final _preguntas = <_Editable>[];
  late final Future<void> _carga = widget.repositorio
      .preguntas(widget.versionId, widget.tema.id, widget.nivel)
      .then((lista) {
        if (!mounted) return;
        setState(
          () => _preguntas.addAll([for (final p in lista) _Editable(p)]),
        );
      });
  bool _ocupado = false;
  String? _mensaje;

  @override
  void dispose() {
    for (final p in _preguntas) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _generar() async {
    setState(() {
      _ocupado = true;
      _mensaje = 'La IA está escribiendo 5 preguntas con el material del tema…';
    });
    try {
      final nuevas = await widget.generador.generar(
        versionId: widget.versionId,
        temaId: widget.tema.id,
        nivel: widget.nivel,
        cantidad: 5,
      );
      if (!mounted) return;
      setState(() {
        _preguntas.addAll([for (final p in nuevas) _Editable(p, deIa: true)]);
        _mensaje =
            '${nuevas.length} preguntas nuevas al final. Revísalas antes de '
            'publicar: la IA puede equivocarse.';
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _mensaje = e is StateError ? e.message : 'No se pudo: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _guardar({required bool publicar}) async {
    final valores = [for (final p in _preguntas) p.valor];
    for (final (i, p) in valores.indexed) {
      if (p.error case final e?) {
        avisarPanel(context, 'Pregunta ${i + 1}: $e');
        return;
      }
    }
    if (publicar && valores.isEmpty) {
      avisarPanel(context, 'Agrega al menos una pregunta para publicar.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      await widget.repositorio.guardarQuiz(
        versionId: widget.versionId,
        tema: widget.tema,
        nivel: widget.nivel,
        preguntas: valores,
        publicar: publicar,
      );
      if (!mounted) return;
      avisarPanel(
        context,
        publicar ? 'Quiz publicado.' : 'Quiz guardado como borrador.',
      );
      widget.onVolver(
        QuizTema(widget.nivel, publicado: publicar, preguntas: valores.length),
      );
    } catch (e) {
      if (mounted) {
        avisarPanel(context, 'No se pudo guardar: $e');
        setState(() => _ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return PaginaPanel(
      children: [
        EncabezadoPanel(
          migas: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _ocupado ? null : () => widget.onVolver(null),
                child: Text(
                  widget.tema.titulo,
                  style: TextStyle(color: p.apagado),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: p.tenue),
              const Text('Quiz'),
            ],
          ),
          titulo: 'Quiz ${widget.nivel.etiqueta.toLowerCase()}',
          subtitulo:
              '${widget.curso.nombre} · ${widget.tema.titulo}. Fórmulas entre '
              r'$…$ (se ven como en la app).',
          acciones: [
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _generar,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generar 5 con IA'),
            ),
            OutlinedButton(
              onPressed: _ocupado ? null : () => _guardar(publicar: false),
              child: const Text('Guardar borrador'),
            ),
            FilledButton.icon(
              onPressed: _ocupado ? null : () => _guardar(publicar: true),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Publicar'),
            ),
          ],
        ),
        if (_mensaje case final m?)
          TarjetaPanel(
            child: Row(
              children: [
                if (_ocupado)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(child: Text(m)),
              ],
            ),
          ),
        FutureBuilder<void>(
          future: _carga,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            return ColumnaPanel(
              children: [
                for (final (i, pregunta) in _preguntas.indexed)
                  _TarjetaPregunta(
                    key: ObjectKey(pregunta),
                    numero: i + 1,
                    pregunta: pregunta,
                    onCambio: () => setState(() {}),
                    onQuitar: () => setState(() {
                      _preguntas.removeAt(i).dispose();
                    }),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _ocupado
                        ? null
                        : () =>
                              setState(() => _preguntas.add(_Editable.vacia())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar pregunta'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TarjetaPregunta extends StatelessWidget {
  final int numero;
  final _Editable pregunta;
  final VoidCallback onCambio;
  final VoidCallback onQuitar;

  const _TarjetaPregunta({
    super.key,
    required this.numero,
    required this.pregunta,
    required this.onCambio,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final error = pregunta.valor.error;
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            'Pregunta $numero',
            extra: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pregunta.deIa)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Insignia(
                      'Generada con IA',
                      tono: TonoInsignia.acento,
                    ),
                  ),
                IconButton(
                  tooltip: 'Quitar pregunta',
                  onPressed: onQuitar,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
          ),
          TextField(
            controller: pregunta.enunciado,
            minLines: 2,
            maxLines: 6,
            onChanged: (_) => onCambio(),
            decoration: const InputDecoration(labelText: 'Enunciado'),
          ),
          if (pregunta.enunciado.text.contains(r'$')) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PaletaPanel.linea,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextoConLatex(pregunta.enunciado.text),
            ),
          ],
          const SizedBox(height: 12),
          for (final (k, opcion) in pregunta.opciones.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Marcar como correcta',
                    onPressed: () {
                      pregunta.correcta = k;
                      onCambio();
                    },
                    icon: Icon(
                      pregunta.correcta == k
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: pregunta.correcta == k ? p.secundario : p.tenue,
                    ),
                  ),
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${PreguntaPractica.letras[k]})',
                      style: TextStyle(color: p.apagado),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: opcion,
                      onChanged: (_) => onCambio(),
                    ),
                  ),
                  if (pregunta.opciones.length > 2)
                    IconButton(
                      tooltip: 'Quitar opción',
                      onPressed: () {
                        pregunta.opciones.removeAt(k).dispose();
                        if (pregunta.correcta == k) {
                          pregunta.correcta = -1;
                        } else if (pregunta.correcta > k) {
                          pregunta.correcta--;
                        }
                        onCambio();
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
            ),
          if (pregunta.opciones.length < 5)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  pregunta.opciones.add(TextEditingController());
                  onCambio();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar opción'),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: pregunta.explicacion,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Explicación (se muestra al responder)',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error, style: TextStyle(color: p.alerta, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
