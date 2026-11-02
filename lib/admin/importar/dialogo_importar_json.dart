import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'importar_json.dart';
import 'subir_imagenes.dart';

/// Lo que eligió el administrador al importar.
class ImportacionElegida {
  final ResultadoImportacion resultado;

  /// true: reemplaza las preguntas actuales; false: se agregan al final.
  final bool reemplazar;

  const ImportacionElegida(this.resultado, {required this.reemplazar});
}

Future<String?> _abrirArchivoJson() async {
  final archivo = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'JSON',
        extensions: ['json'],
        mimeTypes: ['application/json'],
      ),
    ],
  );
  return archivo?.readAsString();
}

/// Pegar o abrir un JSON, revisar qué trae (LaTeX, imágenes, errores) y
/// confirmar. No escribe nada: devuelve lo elegido.
Future<ImportacionElegida?> mostrarImportarJson(
  BuildContext context, {
  required String titulo,
  required String Function(String archivo) urlDeArchivo,

  /// Carpeta donde se suben las imágenes, p. ej. "temas/version-1/algebra-02".
  required String carpetaImagenes,
  bool hayActuales = false,
  ServicioImagenesAdmin? imagenes,
  Future<String?> Function() abrirArchivo = _abrirArchivoJson,
  Future<List<ArchivoImagen>> Function() elegirImagenes =
      elegirImagenesDelComputador,
}) {
  return showDialog<ImportacionElegida>(
    context: context,
    builder: (_) => DialogoImportarJson(
      titulo: titulo,
      urlDeArchivo: urlDeArchivo,
      carpetaImagenes: carpetaImagenes,
      hayActuales: hayActuales,
      imagenes: imagenes,
      abrirArchivo: abrirArchivo,
      elegirImagenes: elegirImagenes,
    ),
  );
}

class DialogoImportarJson extends StatefulWidget {
  final String titulo;
  final String Function(String archivo) urlDeArchivo;
  final String carpetaImagenes;
  final bool hayActuales;
  final ServicioImagenesAdmin? imagenes;
  final Future<String?> Function() abrirArchivo;
  final Future<List<ArchivoImagen>> Function() elegirImagenes;

  const DialogoImportarJson({
    super.key,
    required this.titulo,
    required this.urlDeArchivo,
    required this.carpetaImagenes,
    required this.hayActuales,
    required this.abrirArchivo,
    required this.elegirImagenes,
    this.imagenes,
  });

  @override
  State<DialogoImportarJson> createState() => _DialogoImportarJsonState();
}

class _DialogoImportarJsonState extends State<DialogoImportarJson> {
  final _texto = TextEditingController();
  ResultadoImportacion? _resultado;
  String? _error;
  late bool _reemplazar = widget.hayActuales;

  /// Dirección provisional (por nombre de archivo) -> dirección subida.
  final _subidas = <String, String>{};
  final _subiendo = <String>{};
  String? _avisoImagenes;

  static const _ejemplo = '''{
  "preguntas": [
    {
      "enunciado": "Si \$A/B = 3\$ y \$B = 10\$, ¿cuánto vale \$A\$?",
      "opciones": ["24", "30", "36", "40"],
      "correcta": 1,
      "explicacion": "\$A = 3 \\\\cdot 10 = 30\$",
      "imagen": "figura-01.png"
    }
  ]
}''';

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _revisar() {
    try {
      setState(() {
        _resultado = leerPreguntasJson(
          _texto.text,
          urlDeArchivo: widget.urlDeArchivo,
        );
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _resultado = null;
        _error = e.message;
      });
    }
  }

  Future<void> _abrir() async {
    try {
      final texto = await widget.abrirArchivo();
      if (texto == null || !mounted) return;
      _texto.text = texto;
      _revisar();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir el archivo: $e');
    }
  }

  /// Sube las imágenes elegidas cuyo nombre coincide con las del JSON.
  Future<void> _subirImagenes(Set<String> faltan) async {
    final servicio = widget.imagenes;
    if (servicio == null) return;
    final List<ArchivoImagen> elegidas;
    try {
      elegidas = await widget.elegirImagenes();
    } catch (e) {
      setState(() => _avisoImagenes = 'No se pudo abrir: $e');
      return;
    }
    final porNombre = {for (final n in faltan) n.toLowerCase(): n};
    final sobran = <String>[];
    var errores = 0;
    for (final a in elegidas) {
      final nombre = porNombre[a.nombre.toLowerCase()];
      if (nombre == null) {
        sobran.add(a.nombre);
        continue;
      }
      setState(() => _subiendo.add(nombre));
      try {
        final url = await servicio.subir(
          ruta: '${widget.carpetaImagenes}/$nombre',
          bytes: a.bytes,
        );
        _subidas[widget.urlDeArchivo(nombre)] = url;
      } catch (_) {
        errores++;
      }
      if (mounted) setState(() => _subiendo.remove(nombre));
    }
    if (!mounted) return;
    setState(() {
      _avisoImagenes = [
        if (errores > 0)
          'No se pudieron subir $errores imágenes. Subir archivos necesita el '
              'plan Blaze; para probar ahora abre el panel con el emulador '
              '(--dart-define=EMULADOR_STORAGE=true).',
        if (sobran.isNotEmpty)
          'No están en el JSON (no se usan): ${sobran.join(', ')}.',
      ].join(' ');
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final r = _resultado;
    final alto = MediaQuery.sizeOf(context).height * 0.85;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900, maxHeight: alto),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: ColumnaPanel(
                    espacio: 12,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _abrir,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Abrir archivo .json'),
                          ),
                          Text(
                            'o pega el JSON abajo',
                            style: TextStyle(color: p.apagado),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _texto.text = _ejemplo;
                              _revisar();
                            }),
                            child: const Text('Ver un ejemplo'),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _texto,
                        minLines: 6,
                        maxLines: 12,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          hintText: '{ "preguntas": [ ... ] }',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: _revisar,
                          icon: const Icon(Icons.fact_check_outlined, size: 18),
                          label: const Text('Revisar'),
                        ),
                      ),
                      if (_error case final e?)
                        Text(e, style: TextStyle(color: p.alerta)),
                      if (r != null) ..._revision(r),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (widget.hayActuales) ...[
                    ChoiceChip(
                      label: const Text('Agregar al final'),
                      selected: !_reemplazar,
                      onSelected: (_) => setState(() => _reemplazar = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Reemplazar las actuales'),
                      selected: _reemplazar,
                      onSelected: (_) => setState(() => _reemplazar = true),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed:
                        r == null || r.preguntas.isEmpty || _subiendo.isNotEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            ImportacionElegida(
                              r.conImagenes(_subidas),
                              reemplazar: _reemplazar,
                            ),
                          ),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      r == null
                          ? 'Importar'
                          : 'Importar ${r.preguntas.length} preguntas',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _revision(ResultadoImportacion r) {
    final p = PaletaPanel.de(context);
    final carpetaUrl = widget.urlDeArchivo('');
    final archivos = {for (final x in r.preguntas) ...x.archivosEn(carpetaUrl)};

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Insignia(
            '${r.preguntas.length} listas',
            tono: TonoInsignia.secundario,
          ),
          Insignia('${r.conLatex} con LaTeX', tono: TonoInsignia.acento),
          Insignia('${r.conImagen} con imagen', tono: TonoInsignia.acento),
          if (r.avisos.isNotEmpty)
            Insignia('${r.avisos.length} avisos', tono: TonoInsignia.alerta),
        ],
      ),
      if (archivos.isNotEmpty) _seccionImagenes(archivos),
      for (final a in r.avisos)
        Text('• $a', style: TextStyle(color: p.alerta, fontSize: 13)),
      for (final x in r.preguntas)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PaletaPanel.linea)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                child: Text('${x.numero}', style: TextStyle(color: p.apagado)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      x.enunciado,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Insignia(
                          '${x.opciones.length} alternativas · '
                          '${String.fromCharCode(65 + x.correcta)}',
                        ),
                        if (x.tieneLatex)
                          const Insignia('LaTeX', tono: TonoInsignia.acento),
                        if (x.solucion != null) const Insignia('Solución'),
                        if (x.seccion case final s?) Insignia(s),
                      ],
                    ),
                  ],
                ),
              ),
              for (final provisional in [?x.imagen, ?x.imagenSolucion])
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _subidas[provisional] ?? provisional,
                      width: 64,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 64,
                        height: 48,
                        alignment: Alignment.center,
                        color: p.alerta.withValues(alpha: 0.12),
                        child: Text(
                          'por subir',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.alerta, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _seccionImagenes(Set<String> archivos) {
    final p = PaletaPanel.de(context);
    final faltan = {
      for (final n in archivos)
        if (!_subidas.containsKey(widget.urlDeArchivo(n))) n,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.acento.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.acento.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  faltan.isEmpty
                      ? 'Las ${archivos.length} imágenes están subidas.'
                      : 'Imágenes: ${archivos.length - faltan.length} de '
                            '${archivos.length} subidas. Elige los archivos '
                            'del computador (puedes elegir varios a la vez).',
                  style: const TextStyle(height: 1.4),
                ),
              ),
              if (faltan.isNotEmpty && widget.imagenes != null)
                FilledButton.tonalIcon(
                  onPressed: _subiendo.isNotEmpty
                      ? null
                      : () => _subirImagenes(faltan),
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: const Text('Subir imágenes'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in archivos)
                Chip(
                  avatar: _subiendo.contains(n)
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          faltan.contains(n)
                              ? Icons.cloud_upload_outlined
                              : Icons.check_circle,
                          size: 16,
                          color: faltan.contains(n) ? p.apagado : p.secundario,
                        ),
                  label: Text(n, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (_avisoImagenes case final aviso? when aviso.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(aviso, style: TextStyle(color: p.alerta, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
