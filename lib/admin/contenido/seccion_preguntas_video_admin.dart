import 'package:flutter/material.dart';

import '../../features/academic/domain/entities/pregunta_video.dart';
import '../../features/academic/domain/repositories/repositorio_preguntas_video.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';

const _letras = ['a', 'b', 'c', 'd'];

/// Arma una pregunta del formulario, o dice qué falta. [opciones] son los
/// textos de A a D (las vacías se omiten; hacen falta al menos 2).
({PreguntaVideo? pregunta, String? error}) preguntaVideoDelFormulario({
  required String id,
  required String tiempo,
  required String enunciado,
  required List<String> opciones,
  required String correcta,
  required String explicacion,
  int? duracionMaxima,
}) {
  final segundo = segundosDesdeTexto(tiempo);
  if (segundo == null || segundo < 1) {
    return (pregunta: null, error: 'Escribe el minuto así: 4:30.');
  }
  if (duracionMaxima != null && segundo > duracionMaxima) {
    return (pregunta: null, error: 'Ese minuto pasa el final del video.');
  }
  if (enunciado.trim().isEmpty) {
    return (pregunta: null, error: 'Escribe la pregunta.');
  }
  final lista = [
    for (final (i, texto) in opciones.indexed)
      if (texto.trim().isNotEmpty)
        OpcionVideo(id: _letras[i], texto: texto.trim()),
  ];
  if (lista.length < 2) {
    return (pregunta: null, error: 'Pon al menos dos alternativas.');
  }
  if (!lista.any((o) => o.id == correcta)) {
    return (pregunta: null, error: 'La correcta tiene que tener texto.');
  }
  return (
    pregunta: PreguntaVideo(
      id: id,
      segundo: segundo,
      enunciado: enunciado.trim(),
      opciones: lista,
      correctaId: correcta,
      explicacion: explicacion.trim().isEmpty ? null : explicacion.trim(),
    ),
    error: null,
  );
}

/// Preguntas dentro de la clase de un tema: la lista (por minuto) y el
/// formulario para agregar una.
class SeccionPreguntasVideoAdmin extends StatefulWidget {
  final String versionId;
  final String temaId;
  final RepositorioPreguntasVideo repositorio;

  /// Para los ids de las preguntas nuevas (inyectable en pruebas).
  final DateTime Function() ahora;

  const SeccionPreguntasVideoAdmin({
    super.key,
    required this.versionId,
    required this.temaId,
    required this.repositorio,
    this.ahora = DateTime.now,
  });

  @override
  State<SeccionPreguntasVideoAdmin> createState() =>
      _SeccionPreguntasVideoAdminState();
}

class _SeccionPreguntasVideoAdminState
    extends State<SeccionPreguntasVideoAdmin> {
  late Future<List<PreguntaVideo>> _lista = _leer();

  final _tiempo = TextEditingController();
  final _enunciado = TextEditingController();
  final _opciones = [for (final _ in _letras) TextEditingController()];
  final _explicacion = TextEditingController();
  String _correcta = _letras.first;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_tiempo, _enunciado, _explicacion, ..._opciones]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<List<PreguntaVideo>> _leer() => widget.repositorio.delTema(
    versionId: widget.versionId,
    temaId: widget.temaId,
  );

  /// true si se guardó.
  Future<bool> _guardar(List<PreguntaVideo> lista, String aviso) async {
    setState(() => _guardando = true);
    try {
      await widget.repositorio.guardar(
        versionId: widget.versionId,
        temaId: widget.temaId,
        preguntas: lista..sort((a, b) => a.segundo.compareTo(b.segundo)),
      );
      if (!mounted) return true;
      setState(() {
        _lista = _leer();
      });
      avisarPanel(context, aviso);
      return true;
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo guardar: $e');
      return false;
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregar(List<PreguntaVideo> actuales) async {
    final (:pregunta, :error) = preguntaVideoDelFormulario(
      id: 'p${widget.ahora().millisecondsSinceEpoch}',
      tiempo: _tiempo.text,
      enunciado: _enunciado.text,
      opciones: [for (final c in _opciones) c.text],
      correcta: _correcta,
      explicacion: _explicacion.text,
    );
    if (pregunta == null) {
      avisarPanel(context, error ?? 'Revisa la pregunta.');
      return;
    }
    final guardada = await _guardar([...actuales, pregunta], 'Pregunta agregada.');
    if (!guardada || !mounted) return;
    for (final c in [_tiempo, _enunciado, _explicacion, ..._opciones]) {
      c.clear();
    }
    setState(() => _correcta = _letras.first);
  }

  Future<void> _eliminar(
    List<PreguntaVideo> actuales,
    PreguntaVideo pregunta,
  ) async {
    final ok = await confirmarPanel(
      context,
      titulo: 'Eliminar pregunta',
      mensaje: 'La pregunta del ${textoDeSegundos(pregunta.segundo)} dejará '
          'de salir en la clase.',
      confirmar: 'Eliminar',
      peligro: true,
    );
    if (!ok || !mounted) return;
    await _guardar(
      [for (final p in actuales) if (p.id != pregunta.id) p],
      'Pregunta eliminada.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return FutureBuilder<List<PreguntaVideo>>(
      future: _lista,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        if (s.hasError) {
          return Text(
            'No se pudieron leer las preguntas.',
            style: TextStyle(color: p.alerta),
          );
        }
        final lista = s.data ?? const <PreguntaVideo>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lista.isEmpty)
              Text(
                'Sin preguntas todavía.',
                style: TextStyle(color: p.apagado),
              ),
            for (final pregunta in lista)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: PaletaPanel.linea)),
                ),
                child: Row(
                  children: [
                    Insignia(
                      textoDeSegundos(pregunta.segundo),
                      tono: TonoInsignia.secundario,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pregunta.enunciado,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Correcta: ${pregunta.correcta?.texto ?? ''}',
                            style: TextStyle(color: p.apagado, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: _guardando
                          ? null
                          : () => _eliminar(lista, pregunta),
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Agregar pregunta',
              style: TextStyle(color: p.apagado, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tiempo,
              decoration: const InputDecoration(
                labelText: 'Minuto del video',
                hintText: '4:30',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _enunciado,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Pregunta'),
            ),
            for (final (i, c) in _opciones.indexed) ...[
              const SizedBox(height: 12),
              TextField(
                controller: c,
                decoration: InputDecoration(
                  labelText:
                      'Alternativa ${_letras[i].toUpperCase()}'
                      '${i < 2 ? '' : ' (opcional)'}',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Correcta:', style: TextStyle(color: p.apagado)),
                for (final letra in _letras)
                  ChoiceChip(
                    label: Text(letra.toUpperCase()),
                    selected: _correcta == letra,
                    onSelected: (_) => setState(() => _correcta = letra),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _explicacion,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Explicación (opcional)',
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _guardando ? null : () => _agregar(lista),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar pregunta'),
              ),
            ),
          ],
        );
      },
    );
  }
}
