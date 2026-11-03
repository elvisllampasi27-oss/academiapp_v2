import 'package:flutter/material.dart';

import '../../core/presentation/texto.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../importar/dialogo_importar_json.dart';
import '../importar/importar_json.dart';
import '../importar/subir_imagenes.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'editor_pregunta.dart';
import 'modelo_examen_admin.dart';
import 'repositorio_examenes_admin.dart';

enum _Filtro { todas, sinSolucion, inactivas }

/// Exámenes pasados o semanales: lista de exámenes, sus preguntas y el
/// editor. Los semanales se importan por versión y semana.
class ExamenesAdminPage extends StatefulWidget {
  final RepositorioExamenesAdmin repositorio;

  /// Con esto la pantalla maneja los exámenes semanales (si no, los
  /// pasados).
  final Future<List<VersionAcademica>> Function()? versionesSemanales;

  /// Para subir figuras (por defecto, Firebase Storage).
  final ServicioImagenesAdmin? imagenes;

  /// Para abrir directo un examen y una pregunta (desde un reporte).
  final String? examenInicial;
  final String? preguntaInicial;

  const ExamenesAdminPage({
    super.key,
    required this.repositorio,
    this.imagenes,
    this.examenInicial,
    this.preguntaInicial,
    this.versionesSemanales,
  });

  bool get semanales => versionesSemanales != null;

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

  @override
  void initState() {
    super.initState();
    if (widget.examenInicial case final id?) {
      _examenes.then((examenes) {
        final examen = examenes.where((e) => e.id == id).firstOrNull;
        if (examen != null && mounted) {
          _elegirExamen(examen, preguntaId: widget.preguntaInicial);
        }
      }, onError: (_) {});
    }
  }

  Future<void> _elegirExamen(ExamenAdmin examen, {String? preguntaId}) async {
    setState(() {
      _examen = examen;
      _preguntas = null;
      _editando = null;
      _cargandoPreguntas = true;
    });
    try {
      final preguntas = await widget.repositorio.preguntas(examen.id);
      if (!mounted || _examen?.id != examen.id) return;
      setState(() {
        _preguntas = preguntas;
        _editando = preguntas.where((p) => p.id == preguntaId).firstOrNull;
      });
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

  Future<void> _eliminarPregunta(PreguntaAdmin pregunta) async {
    final ok = await confirmarPanel(
      context,
      titulo: 'Eliminar la pregunta #${pregunta.numero}',
      mensaje:
          'Se borran la pregunta y su clave. Deja de salir para los '
          'estudiantes y no se puede recuperar. Si solo '
          'quieres sacarla un tiempo, desactívala.',
      confirmar: 'Eliminar',
      peligro: true,
    );
    if (!ok) return;
    final restantes = [
      for (final p in _preguntas ?? const <PreguntaAdmin>[])
        if (p.id != pregunta.id) p,
    ];
    try {
      await widget.repositorio.eliminarPregunta(pregunta, restantes: restantes);
      if (!mounted) return;
      setState(() {
        _preguntas = restantes;
        _editando = null;
        _examenes = widget.repositorio.examenes();
      });
      _avisar('Pregunta ${pregunta.numero} eliminada.');
    } catch (_) {
      _avisar('No se pudo eliminar la pregunta.');
    }
  }

  Future<void> _eliminarExamen(ExamenAdmin examen) async {
    final ok = await confirmarPanel(
      context,
      titulo: 'Eliminar ${examen.titulo}',
      mensaje:
          'Se borran el examen y sus ${examen.totalPreguntas} preguntas con '
          'sus claves. No se puede recuperar (tendrías que importar el JSON '
          'de nuevo). Si solo quieres ocultarlo, pásalo a borrador con el ojo.',
      confirmar: 'Eliminar examen',
      peligro: true,
    );
    if (!ok) return;
    try {
      await widget.repositorio.eliminarExamen(examen.id);
      if (!mounted) return;
      setState(() {
        if (_examen?.id == examen.id) {
          _examen = null;
          _preguntas = null;
          _editando = null;
        }
        _examenes = widget.repositorio.examenes();
      });
      _avisar('Examen eliminado.');
    } catch (_) {
      _avisar('No se pudo eliminar el examen. Inténtalo de nuevo.');
    }
  }

  /// Examen completo desde el JSON de la V1 (o el mismo formato).
  Future<void> _importar(List<ExamenAdmin> existentes) async {
    final String examenId;
    final String tipo;
    final String fecha;
    final String titulo;
    final String carpeta;
    var extra = const <String, Object?>{};
    if (widget.versionesSemanales case final versiones?) {
      final datos = await showDialog<(VersionAcademica, int)>(
        context: context,
        builder: (_) => _DialogoSemana(versiones: versiones()),
      );
      if (datos == null || !mounted) return;
      final (version, semana) = datos;
      examenId = idExamenSemanal(version.id, semana);
      tipo = 'semanal';
      fecha = '';
      titulo = 'Semana $semana · ${version.nombre}';
      carpeta = 'semanales/${version.id}/s$semana';
      extra = {'versionId': version.id, 'semana': semana};
    } else {
      final datos = await showDialog<(String, String)>(
        context: context,
        builder: (_) => const _DialogoDatosExamen(),
      );
      if (datos == null || !mounted) return;
      final (t, dia) = datos;
      tipo = t;
      fecha = fechaIsoDeCarpeta(dia)!;
      examenId = '$tipo-$fecha';
      titulo = tituloExamen(tipo, fecha);
      carpeta = 'examenes/$tipo/$dia';
    }
    final yaExiste = existentes.any((e) => e.id == examenId);

    final elegida = await mostrarImportarJson(
      context,
      titulo: 'Importar $titulo',
      urlDeArchivo: (archivo) =>
          '$urlHosting/$carpeta/${Uri.encodeComponent(archivo)}',
      carpetaImagenes: carpeta,
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
        titulo: titulo,
        preguntas: [...actuales, ...preguntas],
        extra: extra,
      );
      _avisar(
        '${preguntas.length} preguntas importadas en $titulo. '
        'Revísalo y publícalo.',
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
            titulo: widget.semanales
                ? 'Exámenes semanales'
                : 'Exámenes pasados',
            subtitulo: widget.semanales
                ? 'Uno por versión y semana. Se abre el sábado de esa semana y '
                      'queda abierto hasta el sábado siguiente; un solo intento. '
                      'Solo se da si está publicado.'
                : 'Los estudiantes los practican y ven la respuesta al '
                      'instante. Elige un examen y luego una pregunta.',
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
              widget.semanales
                  ? 'Todavía no hay exámenes semanales. Importa el de la '
                        'semana 1.'
                  : 'Todavía no hay exámenes. Importa uno.',
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
                                // Wrap: en columnas angostas baja a otra
                                // línea en vez de desbordarse.
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
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
                          IconButton(
                            tooltip: 'Eliminar examen',
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: p.apagado,
                            ),
                            onPressed: () => _eliminarExamen(e),
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
      onEliminar: () => _eliminarPregunta(pregunta),
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

/// Versión y semana del examen semanal a importar.
class _DialogoSemana extends StatefulWidget {
  final Future<List<VersionAcademica>> versiones;

  const _DialogoSemana({required this.versiones});

  @override
  State<_DialogoSemana> createState() => _DialogoSemanaState();
}

class _DialogoSemanaState extends State<_DialogoSemana> {
  VersionAcademica? _version;
  int _semana = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar examen semanal'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<VersionAcademica>>(
          future: widget.versiones,
          builder: (context, s) {
            final versiones = s.data;
            if (versiones == null) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<VersionAcademica>(
                  initialValue: _version,
                  decoration: const InputDecoration(labelText: 'Versión'),
                  items: [
                    for (final v in versiones)
                      DropdownMenuItem(value: v, child: Text(v.nombre)),
                  ],
                  onChanged: (v) => setState(() => _version = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('Semana')),
                    IconButton(
                      tooltip: 'Semana anterior',
                      onPressed: _semana > 1
                          ? () => setState(() => _semana--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$_semana',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Semana siguiente',
                      onPressed: _semana < 52
                          ? () => setState(() => _semana++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Con los temas de esa semana del ciclo. Si ya existe, '
                  'podrás reemplazarlo.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _version == null
              ? null
              : () => Navigator.pop(context, (_version!, _semana)),
          child: const Text('Siguiente'),
        ),
      ],
    );
  }
}
