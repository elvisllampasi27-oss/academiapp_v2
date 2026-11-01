import 'package:flutter/material.dart';

import '../../core/presentation/colores_app.dart';
import '../../core/presentation/texto.dart';
import 'editor_pregunta.dart';
import 'modelo_examen_admin.dart';
import 'repositorio_examenes_admin.dart';

enum _Filtro { todas, sinSolucion, inactivas }

/// Exámenes pasados: lista de exámenes, sus preguntas y el editor.
class ExamenesAdminPage extends StatefulWidget {
  final RepositorioExamenesAdmin repositorio;

  const ExamenesAdminPage({super.key, required this.repositorio});

  @override
  State<ExamenesAdminPage> createState() => _ExamenesAdminPageState();
}

class _ExamenesAdminPageState extends State<ExamenesAdminPage> {
  late Future<List<ExamenAdmin>> _examenes = widget.repositorio.examenes();

  ExamenAdmin? _examen;
  List<PreguntaAdmin>? _preguntas;
  bool _cargandoPreguntas = false;
  PreguntaAdmin? _editando;
  bool _esNueva = false;

  String _busqueda = '';
  _Filtro _filtro = _Filtro.todas;

  Future<void> _elegirExamen(ExamenAdmin examen) async {
    setState(() {
      _examen = examen;
      _preguntas = null;
      _editando = null;
      _cargandoPreguntas = true;
    });
    try {
      final preguntas = await widget.repositorio.preguntas(examen.id);
      if (!mounted || _examen?.id != examen.id) return;
      setState(() => _preguntas = preguntas);
    } catch (_) {
      _avisar('No se pudieron cargar las preguntas.');
    } finally {
      if (mounted) setState(() => _cargandoPreguntas = false);
    }
  }

  void _nuevaPregunta() {
    final examen = _examen;
    final preguntas = _preguntas;
    if (examen == null || preguntas == null) return;

    final numero = preguntas.fold(0, (m, p) => p.numero > m ? p.numero : m) + 1;
    setState(() {
      _esNueva = true;
      _editando = PreguntaAdmin(
        id: PreguntaAdmin.idPara(examen.id, numero),
        examenId: examen.id,
        numero: numero,
        seccion: preguntas.isEmpty ? '' : preguntas.last.seccion,
        enunciado: '',
        opciones: List.filled(5, ''),
        correcta: -1,
      );
    });
  }

  Future<void> _guardar(PreguntaAdmin pregunta) async {
    final preguntas = _preguntas ?? const <PreguntaAdmin>[];
    final anterior = preguntas.where((p) => p.id == pregunta.id).firstOrNull;
    final todas = [
      for (final p in preguntas) p.id == pregunta.id ? pregunta : p,
      if (anterior == null) pregunta,
    ];

    await widget.repositorio.guardar(
      pregunta,
      anterior: anterior,
      todas: todas,
    );

    if (!mounted) return;
    setState(() {
      _preguntas = todas;
      _editando = pregunta;
      _esNueva = false;
      // Para que la lista de exámenes muestre el total nuevo.
      _examenes = widget.repositorio.examenes();
    });
    _avisar('Pregunta ${pregunta.numero} guardada.');
  }

  Future<void> _cambiarEstado(ExamenAdmin examen) async {
    try {
      await widget.repositorio.cambiarEstado(
        examen.id,
        publicado: !examen.publicado,
      );
      if (!mounted) return;
      setState(() => _examenes = widget.repositorio.examenes());
    } catch (_) {
      _avisar('No se pudo cambiar el estado.');
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  List<PreguntaAdmin> _visibles() {
    final consulta = normalizarTexto(_busqueda.trim());
    return [
      for (final p in _preguntas ?? const <PreguntaAdmin>[])
        if (switch (_filtro) {
              _Filtro.todas => true,
              _Filtro.sinSolucion => !p.tieneSolucion,
              _Filtro.inactivas => !p.activa,
            } &&
            (consulta.isEmpty ||
                normalizarTexto(p.enunciado).contains(consulta) ||
                '${p.numero}' == consulta))
          p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 290, child: _listaExamenes()),
        const VerticalDivider(width: 1),
        SizedBox(width: 380, child: _listaPreguntas()),
        const VerticalDivider(width: 1),
        Expanded(child: _editor()),
      ],
    );
  }

  Widget _listaExamenes() {
    return FutureBuilder<List<ExamenAdmin>>(
      future: _examenes,
      builder: (context, snapshot) {
        final examenes = snapshot.data;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Exámenes pasados',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Para cargar exámenes completos usa tool/cargar_examenes.js.',
              style: TextStyle(fontSize: 12, color: ColoresApp.apagado),
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              const Text('No se pudieron cargar los exámenes.')
            else if (examenes == null)
              const Center(child: CircularProgressIndicator())
            else
              for (final e in examenes)
                Card(
                  color: e.id == _examen?.id ? const Color(0x1FFFFFFF) : null,
                  child: ListTile(
                    title: Text(e.titulo),
                    subtitle: Text(
                      '${e.totalPreguntas} preguntas · '
                      '${e.publicado ? 'publicado' : 'borrador'}',
                    ),
                    onTap: () => _elegirExamen(e),
                    trailing: IconButton(
                      tooltip: e.publicado
                          ? 'Pasar a borrador (los estudiantes no lo ven)'
                          : 'Publicar',
                      icon: Icon(
                        e.publicado
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => _cambiarEstado(e),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _listaPreguntas() {
    if (_examen == null) {
      return const Center(
        child: Text(
          'Elige un examen.',
          style: TextStyle(color: ColoresApp.apagado),
        ),
      );
    }
    if (_cargandoPreguntas) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibles = _visibles();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar o número',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (t) => setState(() => _busqueda = t),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _preguntas == null ? null : _nuevaPregunta,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            children: [
              for (final (filtro, texto) in const [
                (_Filtro.todas, 'Todas'),
                (_Filtro.sinSolucion, 'Sin solución'),
                (_Filtro.inactivas, 'Inactivas'),
              ])
                ChoiceChip(
                  label: Text(texto),
                  selected: _filtro == filtro,
                  onSelected: (_) => setState(() => _filtro = filtro),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: visibles.length,
            itemBuilder: (context, i) {
              final p = visibles[i];
              return ListTile(
                selected: p.id == _editando?.id,
                selectedTileColor: const Color(0x1FFFFFFF),
                title: Text(
                  '#${p.numero} · ${p.seccion}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  p.enunciado,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.imagen != null)
                      const Icon(Icons.image_outlined, size: 16),
                    if (!p.tieneSolucion)
                      const Tooltip(
                        message: 'Sin solución',
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: ColoresApp.ambar,
                        ),
                      ),
                    if (!p.activa)
                      const Tooltip(
                        message: 'Inactiva',
                        child: Icon(
                          Icons.block,
                          size: 16,
                          color: ColoresApp.naranja,
                        ),
                      ),
                  ],
                ),
                onTap: () => setState(() {
                  _editando = p;
                  _esNueva = false;
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _editor() {
    final pregunta = _editando;
    if (pregunta == null) {
      return const Center(
        child: Text(
          'Elige una pregunta para editarla.',
          style: TextStyle(color: ColoresApp.apagado),
        ),
      );
    }

    final secciones = {
      for (final p in _preguntas ?? const <PreguntaAdmin>[]) p.seccion,
    }.where((s) => s.isNotEmpty).toList();

    return EditorPregunta(
      key: ValueKey('${pregunta.id}-$_esNueva'),
      pregunta: pregunta,
      esNueva: _esNueva,
      secciones: secciones,
      onGuardar: _guardar,
    );
  }
}
