import 'package:flutter/material.dart';

import '../../features/narrations/domain/narracion.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'narraciones_admin.dart';

/// Narraciones de un tema en el panel: la lista y el formulario para
/// agregar una (audio desde el computador o, para probar, un enlace).
class SeccionNarracionesAdmin extends StatefulWidget {
  final String versionId;
  final String temaId;
  final String tituloTema;
  final RepositorioNarracionesAdmin repositorio;

  /// Inyectable en pruebas; por defecto el selector de archivos.
  final Future<ArchivoAudio?> Function() elegirAudio;

  const SeccionNarracionesAdmin({
    super.key,
    required this.versionId,
    required this.temaId,
    required this.tituloTema,
    required this.repositorio,
    this.elegirAudio = elegirAudioDelComputador,
  });

  @override
  State<SeccionNarracionesAdmin> createState() =>
      _SeccionNarracionesAdminState();
}

class _SeccionNarracionesAdminState extends State<SeccionNarracionesAdmin> {
  late Future<List<Narracion>> _lista = _leer();

  final _titulo = TextEditingController();
  final _tipoEscrito = TextEditingController();
  final _descripcion = TextEditingController();
  final _enlace = TextEditingController();
  String _tipo = tiposNarracion.first;
  ArchivoAudio? _audio;
  bool _guardando = false;

  /// Cambia al limpiar el formulario (el desplegable vuelve al primero).
  int _formulario = 0;

  @override
  void dispose() {
    for (final c in [_titulo, _tipoEscrito, _descripcion, _enlace]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<List<Narracion>> _leer() => widget.repositorio.delTema(
    versionId: widget.versionId,
    temaId: widget.temaId,
  );

  Future<void> _elegir() async {
    try {
      final audio = await widget.elegirAudio();
      if (audio != null && mounted) setState(() => _audio = audio);
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo leer el audio: $e');
    }
  }

  Future<void> _agregar() async {
    final tipo = tipoElegido(_tipo, _tipoEscrito.text);
    final error = errorNarracion(
      titulo: _titulo.text,
      tipo: tipo,
      audio: _audio,
      enlace: _enlace.text,
    );
    if (error != null) {
      avisarPanel(context, error);
      return;
    }

    setState(() => _guardando = true);
    try {
      await widget.repositorio.agregar(
        versionId: widget.versionId,
        temaId: widget.temaId,
        tituloTema: widget.tituloTema,
        titulo: _titulo.text.trim(),
        tipo: tipo,
        descripcion: _descripcion.text.trim(),
        audio: _audio,
        enlace: _audio == null ? _enlace.text.trim() : null,
      );
      if (!mounted) return;
      for (final c in [_titulo, _tipoEscrito, _descripcion, _enlace]) {
        c.clear();
      }
      setState(() {
        _audio = null;
        _tipo = tiposNarracion.first;
        _formulario++;
        _lista = _leer();
      });
      avisarPanel(context, 'Narración agregada.');
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo agregar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar(Narracion n) async {
    final ok = await confirmarPanel(
      context,
      titulo: 'Eliminar narración',
      mensaje: '"${n.titulo}" dejará de verse en la app.',
      confirmar: 'Eliminar',
      peligro: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.repositorio.eliminar(n);
      if (!mounted) return;
      // Con llaves: setState no acepta una función que devuelva un Future.
      setState(() {
        _lista = _leer();
      });
      avisarPanel(context, 'Narración eliminada.');
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final audio = _audio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<List<Narracion>>(
          future: _lista,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            if (s.hasError) {
              return Text(
                'No se pudieron leer las narraciones.',
                style: TextStyle(color: p.alerta),
              );
            }
            final lista = s.data ?? const [];
            if (lista.isEmpty) {
              return Text(
                'Sin narraciones todavía.',
                style: TextStyle(color: p.apagado),
              );
            }
            return Column(
              children: [
                for (final n in lista)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: PaletaPanel.linea),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.headphones_outlined, color: p.apagado),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.titulo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                n.rutaAudio == null
                                    ? 'Enlace pegado (prueba)'
                                    : 'Audio subido',
                                style: TextStyle(
                                  color: p.apagado,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Insignia(n.tipo, tono: TonoInsignia.secundario),
                        IconButton(
                          tooltip: 'Eliminar',
                          onPressed: () => _eliminar(n),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Agregar narración',
          style: TextStyle(color: p.apagado, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titulo,
          decoration: const InputDecoration(
            labelText: 'Título',
            hintText: 'La batalla de Ayacucho',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('tipo-$_formulario'),
          initialValue: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [
            for (final t in [...tiposNarracion, tipoOtro])
              DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (t) => setState(() => _tipo = t ?? _tipo),
        ),
        if (_tipo == tipoOtro) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _tipoEscrito,
            decoration: const InputDecoration(
              labelText: 'Escribe el tipo',
              hintText: 'Crónica, fábula, poema…',
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _descripcion,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Descripción (opcional)',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _guardando ? null : _elegir,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Elegir audio'),
            ),
            if (audio != null)
              InputChip(
                label: Text('${audio.nombre} · ${tamanoLegible(audio.tamano)}'),
                onDeleted: () => setState(() => _audio = null),
              )
            else
              Text(
                'MP3 o M4A, hasta ${tamanoLegible(maxBytesAudio)}.',
                style: TextStyle(color: p.tenue, fontSize: 12),
              ),
          ],
        ),
        if (audio == null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _enlace,
            decoration: const InputDecoration(
              labelText: 'O pega un enlace (solo para probar)',
              hintText: 'https://…/audio.mp3',
            ),
          ),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _guardando ? null : _agregar,
            icon: _guardando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add, size: 18),
            label: Text(_guardando ? 'Subiendo…' : 'Agregar narración'),
          ),
        ),
      ],
    );
  }
}
