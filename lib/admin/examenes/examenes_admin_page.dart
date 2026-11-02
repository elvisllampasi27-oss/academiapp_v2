import 'package:flutter/material.dart';

import '../../core/presentation/texto.dart';
import '../importar/dialogo_importar_json.dart';
import '../importar/importar_json.dart';
import '../importar/subir_imagenes.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'editor_pregunta.dart';
import 'modelo_examen_admin.dart';
import 'repositorio_examenes_admin.dart';

enum _Filtro { todas, sinSolucion, inactivas }

/// Exámenes pasados: lista de exámenes, sus preguntas y el editor.
class ExamenesAdminPage extends StatefulWidget {
  final RepositorioExamenesAdmin repositorio;

  /// Para subir figuras (por defecto, Firebase Storage).
  final ServicioImagenesAdmin? imagenes;

  const ExamenesAdminPage({
    super.key,
    required this.repositorio,
    this.imagenes,
  });

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
      setState(() {
        _examenes = widget.repositorio.examenes();
      });
    } catch (_) {
      _avisar('No se pudo cambiar el estado.');
    }
  }

  /// Examen completo desde el JSON de la V1 (o el mismo formato).
  Future<void> _importar(List<ExamenAdmin> existentes) async {
    final datos = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _DialogoDatosExamen(),
    );
    if (datos == null || !mounted) return;
    final (tipo, carpeta) = datos;
    final fecha = fechaIsoDeCarpeta(carpeta)!;
    final examenId = '$tipo-$fecha';
    final yaExiste = existentes.any((e) => e.id == examenId);

    final elegida = await mostrarImportarJson(
      context,
      titulo: 'Importar ${tituloExamen(tipo, fecha)}',
      urlDeArchivo: (archivo) =>
          '$urlHosting/examenes/$tipo/$carpeta/${Uri.encodeComponent(archivo)}',
      carpetaImagenes: 'examenes/$tipo/$carpeta',
      hayActuales: yaExiste,
      imagenes: widget.imagenes ?? ServicioImagenesStorage(),
    );
    if (elegida == null || !mounted) return;

    try {
      final actuales = yaExiste && !elegida.reemplazar
          ? await widget.repositorio.preguntas(examenId)
          : const <PreguntaAdmin>[];
      final desde = actuales.fold<int>(
        0,
        (m, p) => p.numero > m ? p.numero : m,
      );
      final r = elegida.resultado;
      final preguntas = [
        for (final (i, x) in r.preguntas.indexed)
          PreguntaAdmin(
            id: PreguntaAdmin.idPara(examenId, desde + i + 1),
            examenId: examenId,
            numero: desde + i + 1,
            seccion: r.seccionDe(x),
            enunciado: x.enunciado,
            opciones: x.opciones,
            correcta: x.correcta,
            solucion: x.solucion,
            imagen: x.imagen,
            imagenSolucion: x.imagenSolucion,
          ),
      ];
      await widget.repositorio.importar(
        examenId: examenId,
        tipo: tipo,
        fecha: fecha,
        titulo: tituloExamen(tipo, fecha),
        preguntas: [...actuales, ...preguntas],
      );
      _avisar(
        '${preguntas.length} preguntas importadas en '
        '${tituloExamen(tipo, fecha)}. Revísalo y publícalo.',
      );
      if (mounted) {
        setState(() {
          _examenes = widget.repositorio.examenes();
        });
      }
    } catch (e) {
      _avisar('No se pudo importar: $e');
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoPanel(
            titulo: 'Exámenes pasados',
            subtitulo:
                'Los estudiantes los practican y el examen tipo admisión toma '
                'de aquí sus preguntas. Elige un examen y luego una pregunta.',
            acciones: [
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _examenes = widget.repositorio.examenes();
                }),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
              ),
              FilledButton.icon(
                onPressed: () async => _importar(await _examenes),
                icon: const Icon(Icons.data_object, size: 18),
                label: const Text('Importar examen (JSON)'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 300,
                  child: TarjetaPanel(
                    padding: const EdgeInsets.all(10),
                    child: _listaExamenes(),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 380,
                  child: TarjetaPanel(
                    padding: EdgeInsets.zero,
                    child: _listaPreguntas(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TarjetaPanel(
                    padding: EdgeInsets.zero,
                    child: _editor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaExamenes() {
    final p = PaletaPanel.de(context);
    return FutureBuilder<List<ExamenAdmin>>(
      future: _examenes,
      builder: (context, snapshot) {
        final examenes = snapshot.data;
        if (snapshot.hasError) {
          return const Center(child: Text('No se pudieron cargar.'));
        }
        if (examenes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (examenes.isEmpty) {
          return Center(
            child: Text(
              'Todavía no hay exámenes. Importa uno.',
              style: TextStyle(color: p.apagado),
            ),
          );
        }
        return ListView(
          children: [
            for (final e in examenes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: e.id == _examen?.id
                      ? const Color(0x14FFFFFF)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: e.id == _examen?.id
                          ? p.acento.withValues(alpha: 0.6)
                          : Colors.transparent,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _elegirExamen(e),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.titulo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    e.publicado
                                        ? const Insignia(
                                            'Publicado',
                                            tono: TonoInsignia.secundario,
                                          )
                                        : const Insignia(
                                            'Borrador',
                                            tono: TonoInsignia.acento,
                                          ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${e.totalPreguntas} preguntas',
                                      style: TextStyle(
                                        color: p.apagado,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: e.publicado
                                ? 'Pasar a borrador (los estudiantes no lo ven)'
                                : 'Publicar',
                            icon: Icon(
                              e.publicado
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: p.apagado,
                            ),
                            onPressed: () => _cambiarEstado(e),
                          ),
                        ],
                      ),
                    ),
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
      return Center(
        child: Text(
          'Elige un examen.',
          style: TextStyle(color: PaletaPanel.de(context).apagado),
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
                selectedTileColor: const Color(0x14FFFFFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                      Tooltip(
                        message: 'Sin solución',
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: PaletaPanel.de(context).acento,
                        ),
                      ),
                    if (!p.activa)
                      Tooltip(
                        message: 'Inactiva',
                        child: Icon(
                          Icons.block,
                          size: 16,
                          color: PaletaPanel.de(context).alerta,
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
      return Center(
        child: Text(
          'Elige una pregunta para editarla.',
          style: TextStyle(color: PaletaPanel.de(context).apagado),
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

/// Tipo y fecha del examen a importar (como las carpetas de la V1).
class _DialogoDatosExamen extends StatefulWidget {
  const _DialogoDatosExamen();

  @override
  State<_DialogoDatosExamen> createState() => _DialogoDatosExamenState();
}

class _DialogoDatosExamenState extends State<_DialogoDatosExamen> {
  final _fecha = TextEditingController();
  String _tipo = 'exonerados';

  @override
  void dispose() {
    _fecha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valida = fechaIsoDeCarpeta(_fecha.text) != null;
    return AlertDialog(
      title: const Text('Importar examen'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final (valor, etiqueta) in const [
                  ('exonerados', 'Exonerados'),
                  ('ordinario', 'Ordinario'),
                ])
                  ChoiceChip(
                    label: Text(etiqueta),
                    selected: _tipo == valor,
                    onSelected: (_) => setState(() => _tipo = valor),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _fecha,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Fecha del examen (dd-mm-aaaa)',
                hintText: '16-11-2025',
                helperText: 'Si ya existe ese examen, podrás reemplazarlo.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: valida
              ? () => Navigator.pop(context, (_tipo, _fecha.text.trim()))
              : null,
          child: const Text('Siguiente'),
        ),
      ],
    );
  }
}
