import 'package:flutter/material.dart';

import '../../core/presentation/colores_app.dart';
import '../../core/presentation/texto_con_latex.dart';
import 'modelo_examen_admin.dart';

/// Formulario de una pregunta con vista previa (como la ve el estudiante).
class EditorPregunta extends StatefulWidget {
  final PreguntaAdmin pregunta;
  final bool esNueva;
  final List<String> secciones;
  final Future<void> Function(PreguntaAdmin pregunta) onGuardar;

  const EditorPregunta({
    super.key,
    required this.pregunta,
    required this.esNueva,
    required this.secciones,
    required this.onGuardar,
  });

  @override
  State<EditorPregunta> createState() => _EditorPreguntaState();
}

class _EditorPreguntaState extends State<EditorPregunta> {
  late final _seccion = TextEditingController(text: widget.pregunta.seccion);
  late final _enunciado = TextEditingController(
    text: widget.pregunta.enunciado,
  );
  late final _solucion = TextEditingController(
    text: widget.pregunta.solucion ?? '',
  );
  late final _imagen = TextEditingController(
    text: widget.pregunta.imagen ?? '',
  );
  late final _imagenSolucion = TextEditingController(
    text: widget.pregunta.imagenSolucion ?? '',
  );
  late final List<TextEditingController> _opciones = [
    for (final o in widget.pregunta.opciones) TextEditingController(text: o),
  ];
  late int _correcta = widget.pregunta.correcta;
  late bool _activa = widget.pregunta.activa;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _seccion,
      _enunciado,
      _solucion,
      _imagen,
      _imagenSolucion,
      ..._opciones,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _url(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  PreguntaAdmin _armar() => PreguntaAdmin(
    id: widget.pregunta.id,
    examenId: widget.pregunta.examenId,
    numero: widget.pregunta.numero,
    seccion: _seccion.text,
    enunciado: _enunciado.text,
    opciones: [for (final c in _opciones) c.text],
    correcta: _correcta,
    solucion: _solucion.text,
    imagen: _url(_imagen),
    imagenSolucion: _url(_imagenSolucion),
    activa: _activa,
  );

  Future<void> _guardar() async {
    final pregunta = _armar();
    final error = pregunta.validar();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.onGuardar(pregunta);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar. Revisa tu permiso de administrador '
              'o la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _agregarOpcion() {
    if (_opciones.length >= PreguntaAdmin.letras.length) return;
    setState(() => _opciones.add(TextEditingController()));
  }

  void _quitarOpcion(int i) {
    if (_opciones.length <= 2) return;
    setState(() {
      _opciones.removeAt(i).dispose();
      if (_correcta == i) {
        _correcta = -1;
      } else if (_correcta > i) {
        _correcta--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pregunta;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.esNueva
                      ? 'Nueva pregunta #${p.numero}'
                      : 'Pregunta #${p.numero}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Text('Activa'),
              Switch(
                value: _activa,
                onChanged: (v) => setState(() => _activa = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _seccion,
            decoration: const InputDecoration(labelText: 'Sección (área)'),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in widget.secciones)
                ActionChip(
                  label: Text(s),
                  onPressed: () => setState(() => _seccion.text = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ConVistaPrevia(
            controller: _enunciado,
            etiqueta: 'Enunciado (fórmulas entre \$...\$)',
          ),
          const SizedBox(height: 12),
          _CampoImagen(controller: _imagen, etiqueta: 'Imagen de la pregunta'),
          const SizedBox(height: 20),
          const Text(
            'Alternativas · marca la correcta',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          RadioGroup<int>(
            groupValue: _correcta,
            onChanged: (v) => setState(() => _correcta = v ?? -1),
            child: Column(
              children: [
                for (final (i, c) in _opciones.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(value: i),
                        SizedBox(
                          width: 24,
                          child: Text(
                            String.fromCharCode(65 + i),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: c,
                            decoration: const InputDecoration(isDense: true),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar',
                          onPressed: _opciones.length <= 2
                              ? null
                              : () => _quitarOpcion(i),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _opciones.length >= PreguntaAdmin.letras.length
                  ? null
                  : _agregarOpcion,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar alternativa'),
            ),
          ),
          const SizedBox(height: 16),
          _ConVistaPrevia(
            controller: _solucion,
            etiqueta: 'Solución (opcional)',
          ),
          const SizedBox(height: 12),
          _CampoImagen(
            controller: _imagenSolucion,
            etiqueta: 'Imagen de la solución (opcional)',
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: ColoresApp.naranja),
              ),
            ),
          Row(
            children: [
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: Text(_guardando ? 'Guardando…' : 'Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Campo de texto con la vista previa debajo (LaTeX incluido).
class _ConVistaPrevia extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;

  const _ConVistaPrevia({required this.controller, required this.etiqueta});

  @override
  State<_ConVistaPrevia> createState() => _ConVistaPreviaState();
}

class _ConVistaPreviaState extends State<_ConVistaPrevia> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          minLines: 2,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: widget.etiqueta),
        ),
        if (widget.controller.text.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColoresApp.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColoresApp.borde),
            ),
            child: TextoConLatex(widget.controller.text),
          ),
      ],
    );
  }
}

/// Enlace https de una imagen con vista previa.
class _CampoImagen extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;

  const _CampoImagen({required this.controller, required this.etiqueta});

  @override
  State<_CampoImagen> createState() => _CampoImagenState();
}

class _CampoImagenState extends State<_CampoImagen> {
  @override
  Widget build(BuildContext context) {
    final url = widget.controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            hintText: 'https://academiapp-v2-7b9ce.web.app/examenes/...',
          ),
        ),
        if (url.startsWith('https://'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ColoredBox(
                color: Colors.white,
                child: Image.network(
                  url,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No se pudo cargar la imagen.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
