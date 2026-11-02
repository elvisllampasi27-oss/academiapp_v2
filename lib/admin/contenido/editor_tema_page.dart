import 'package:flutter/material.dart';

import '../../features/academic/domain/entities/curso.dart';
import '../../features/academic/domain/entities/tema.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'editor_quiz_page.dart';
import 'modelo_contenido.dart';
import 'repositorio_contenido_admin.dart';

/// Todo el material de un tema: clase, contenidos, quizzes, separata,
/// material del tutor y publicación.
class EditorTemaPage extends StatefulWidget {
  final String versionId;
  final Tema tema;
  final Curso curso;
  final MaterialTema material;
  final bool publicado;
  final RepositorioContenidoAdmin repositorio;
  final GeneradorQuiz generador;

  /// true si se guardó algo (para volver a leer la lista).
  final ValueChanged<bool> onVolver;

  const EditorTemaPage({
    super.key,
    required this.versionId,
    required this.tema,
    required this.curso,
    required this.material,
    required this.publicado,
    required this.repositorio,
    required this.generador,
    required this.onVolver,
  });

  @override
  State<EditorTemaPage> createState() => _EditorTemaPageState();
}

class _EditorTemaPageState extends State<EditorTemaPage> {
  late final _titulo = TextEditingController(text: widget.tema.titulo);
  late final _video = TextEditingController(text: widget.material.video ?? '');
  late final _separata = TextEditingController(
    text: widget.material.separata ?? '',
  );
  late final List<TextEditingController> _contenidos = [
    for (final c in widget.material.contenidos) TextEditingController(text: c),
  ];
  final _tutor = TextEditingController();
  late final Future<void> _cargaTutor = widget.repositorio
      .materialTutor(widget.versionId, widget.tema.id)
      .then((t) => _tutor.text = t);

  late bool _publicado = widget.publicado;
  bool _guardando = false;
  bool _cambio = false;
  NivelQuiz? _quiz;

  /// Quizzes guardados en esta pantalla (el resumen se vuelve a leer al
  /// salir).
  late final Map<NivelQuiz, QuizTema> _quizzes = {...widget.material.quizzes};

  @override
  void dispose() {
    for (final c in [_titulo, _video, _separata, _tutor, ..._contenidos]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _errorFormulario {
    if (_titulo.text.trim().length < 3) return 'Escribe el título del tema.';
    if (_video.text.trim().isNotEmpty && idYoutube(_video.text) == null) {
      return 'El enlace del video no es de YouTube.';
    }
    if (_separata.text.trim().isNotEmpty && !enlaceValido(_separata.text)) {
      return 'El enlace de la separata debe empezar con https://';
    }
    return null;
  }

  Future<void> _guardar() async {
    final error = _errorFormulario;
    if (error != null) {
      avisarPanel(context, error);
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.repositorio.guardarTema(
        versionId: widget.versionId,
        tema: widget.tema,
        titulo: _titulo.text.trim(),
        video: _video.text.trim().isEmpty ? null : idYoutube(_video.text),
        separata: _separata.text.trim().isEmpty ? null : _separata.text.trim(),
        contenidos: [
          for (final c in _contenidos)
            if (c.text.trim().isNotEmpty) c.text.trim(),
        ],
        materialTutor: _tutor.text.trim(),
      );
      _cambio = true;
      if (mounted) avisarPanel(context, 'Tema guardado.');
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _publicar(bool publicar) async {
    setState(() => _guardando = true);
    try {
      await widget.repositorio.cambiarPublicacion(
        versionId: widget.versionId,
        tema: widget.tema,
        publicar: publicar,
      );
      _cambio = true;
      if (mounted) {
        setState(() => _publicado = publicar);
        avisarPanel(
          context,
          publicar ? 'Tema publicado.' : 'Tema oculto a los estudiantes.',
        );
      }
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nivel = _quiz;
    if (nivel != null) {
      return EditorQuizPage(
        versionId: widget.versionId,
        tema: widget.tema,
        curso: widget.curso,
        nivel: nivel,
        repositorio: widget.repositorio,
        generador: widget.generador,
        onVolver: (guardado) => setState(() {
          _quiz = null;
          if (guardado != null) {
            _quizzes[guardado.nivel] = guardado;
            _cambio = true;
          }
        }),
      );
    }

    final p = PaletaPanel.de(context);
    final id = idYoutube(_video.text);

    return PaginaPanel(
      children: [
        EncabezadoPanel(
          migas: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => widget.onVolver(_cambio),
                child: Text(
                  'Cursos y temas',
                  style: TextStyle(color: p.apagado),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: p.tenue),
              Text(widget.curso.nombre, style: TextStyle(color: p.apagado)),
              Icon(Icons.chevron_right, size: 16, color: p.tenue),
              Flexible(
                child: Text(
                  widget.tema.titulo,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          titulo: widget.tema.titulo,
          subtitulo: '${widget.curso.nombre} · tema ${widget.tema.orden}',
          acciones: [
            OutlinedButton.icon(
              onPressed: () => widget.onVolver(_cambio),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver'),
            ),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Guardar'),
            ),
          ],
        ),
        DosColumnas(
          flexPrincipal: 3,
          flexLateral: 2,
          principal: ColumnaPanel(
            children: [
              _tarjeta('Tema', [
                TextField(
                  controller: _titulo,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                Text(
                  'El título cambia solo en esta versión. El orden de los '
                  'temas no se cambia aquí: movería el calendario de todos.',
                  style: TextStyle(color: p.tenue, fontSize: 12),
                ),
              ]),
              _tarjeta('Clase (video)', [
                TextField(
                  controller: _video,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Enlace de YouTube',
                    hintText: 'https://youtu.be/…',
                  ),
                ),
                if (id != null)
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://i.ytimg.com/vi/$id/mqdefault.jpg',
                          width: 200,
                          height: 112,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 200,
                            height: 112,
                            color: PaletaPanel.linea,
                            child: Icon(Icons.play_circle, color: p.tenue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Video $id. El quiz se activa cuando el estudiante '
                          've el 90 % de la clase.',
                          style: TextStyle(color: p.apagado),
                        ),
                      ),
                    ],
                  )
                else if (_video.text.trim().isNotEmpty)
                  Text(
                    'No reconozco ese enlace de YouTube.',
                    style: TextStyle(color: p.alerta),
                  ),
              ]),
              _tarjeta(
                'Qué aprenderás (contenidos)',
                [
                  for (final (i, c) in _contenidos.indexed)
                    Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${i + 1}.',
                            style: TextStyle(color: p.apagado),
                          ),
                        ),
                        Expanded(child: TextField(controller: c)),
                        IconButton(
                          tooltip: 'Quitar',
                          onPressed: () => setState(() {
                            _contenidos.removeAt(i).dispose();
                          }),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  if (_contenidos.isEmpty)
                    Text(
                      'Sin contenidos todavía.',
                      style: TextStyle(color: p.apagado),
                    ),
                  Text(
                    'Se comparten entre todas las versiones (son del tema).',
                    style: TextStyle(color: p.tenue, fontSize: 12),
                  ),
                ],
                extra: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _contenidos.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ),
              _tarjeta('Quiz del tema', [
                for (final n in NivelQuiz.values) _filaQuiz(n),
              ]),
            ],
          ),
          lateral: ColumnaPanel(
            children: [
              _tarjeta('Separata (PDF)', [
                TextField(
                  controller: _separata,
                  decoration: const InputDecoration(
                    labelText: 'Enlace del PDF',
                    hintText: 'https://…',
                  ),
                ),
                Text(
                  'Se abre desde el botón + del tema en la app.',
                  style: TextStyle(color: p.tenue, fontSize: 12),
                ),
              ]),
              _tarjeta('Material para el tutor y para generar quizzes', [
                Text(
                  'El tutor responde y la IA arma el quiz con este texto. '
                  'Pega aquí la teoría de la separata o lo esencial de la '
                  'clase.',
                  style: TextStyle(color: p.apagado, height: 1.45),
                ),
                FutureBuilder<void>(
                  future: _cargaTutor,
                  builder: (context, s) => TextField(
                    controller: _tutor,
                    enabled: s.connectionState == ConnectionState.done,
                    minLines: 8,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      hintText: 'Un polinomio es una expresión algebraica…',
                    ),
                  ),
                ),
              ]),
              _tarjeta(
                'Publicación',
                [
                  Text(
                    _publicado
                        ? 'Los estudiantes ya lo ven. Puedes ocultarlo si el '
                              'material tiene un error.'
                        : 'Todavía no lo ven los estudiantes. Normalmente se '
                              'publica con el calendario (Versiones).',
                    style: TextStyle(color: p.apagado, height: 1.45),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _guardando
                          ? null
                          : () => _publicar(!_publicado),
                      icon: Icon(
                        _publicado
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _publicado
                            ? 'Ocultar a los estudiantes'
                            : 'Publicar ahora',
                      ),
                    ),
                  ),
                ],
                extra: _publicado
                    ? const Insignia('Publicado', tono: TonoInsignia.secundario)
                    : const Insignia('Sin publicar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filaQuiz(NivelQuiz n) {
    final p = PaletaPanel.de(context);
    final q = _quizzes[n];
    final cantidad = q?.preguntas ?? 0;
    final (detalle, insignia) = cantidad == 0
        ? ('Sin preguntas', const Insignia('Vacío'))
        : q!.publicado
        ? (
            '$cantidad preguntas · publicado',
            const Insignia('Publicado', tono: TonoInsignia.secundario),
          )
        : (
            '$cantidad preguntas sin publicar',
            const Insignia('Borrador', tono: TonoInsignia.acento),
          );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaletaPanel.linea)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.etiqueta,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(detalle, style: TextStyle(color: p.apagado, fontSize: 13)),
              ],
            ),
          ),
          insignia,
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _quiz = n),
            icon: Icon(
              cantidad == 0 ? Icons.add : Icons.edit_outlined,
              size: 18,
            ),
            label: Text(cantidad == 0 ? 'Crear' : 'Editar'),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(String titulo, List<Widget> hijos, {Widget? extra}) =>
      TarjetaPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloTarjeta(titulo, extra: extra),
            ColumnaPanel(espacio: 12, children: hijos),
          ],
        ),
      );
}
