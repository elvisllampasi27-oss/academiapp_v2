import 'package:flutter/material.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/video/id_youtube.dart';
import '../../academic/domain/entities/curriculo.dart';
import '../../academic/domain/entities/curso.dart';
import '../../academic/domain/entities/tema.dart';
import '../domain/clase_docente.dart';

/// Lo que ve el docente aprobado: el botón para enviar una clase y las que
/// ya envió, con su estado.
class ClasesDelDocente extends StatefulWidget {
  final String uid;
  final String nombre;
  final RepositorioClasesDocente repositorio;

  /// Temario para elegir el tema (null: no se puede enviar desde aquí).
  final Future<Curriculo?> Function()? temario;

  const ClasesDelDocente({
    super.key,
    required this.uid,
    required this.nombre,
    required this.repositorio,
    required this.temario,
  });

  @override
  State<ClasesDelDocente> createState() => _ClasesDelDocenteState();
}

class _ClasesDelDocenteState extends State<ClasesDelDocente> {
  late Future<List<ClaseDocente>> _mias = widget.repositorio.mias(widget.uid);
  bool _leyendoTemario = false;

  void _avisar(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _nueva(Future<Curriculo?> Function() temario) async {
    setState(() => _leyendoTemario = true);
    final leido = await temario().catchError((Object _) => null);
    if (!mounted) return;
    setState(() => _leyendoTemario = false);
    if (leido == null || leido.temas.isEmpty) {
      _avisar('No se pudo leer el temario. Inténtalo en un momento.');
      return;
    }

    final enviada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EnviarClaseDocentePage(
          uid: widget.uid,
          nombre: widget.nombre,
          curriculo: leido,
          repositorio: widget.repositorio,
        ),
      ),
    );
    if (enviada != true || !mounted) return;
    setState(() {
      _mias = widget.repositorio.mias(widget.uid);
    });
    _avisar('Clase enviada. La verán los alumnos al aprobarla.');
  }

  @override
  Widget build(BuildContext context) {
    final temario = widget.temario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (temario != null)
          FilledButton.icon(
            onPressed: _leyendoTemario ? null : () => _nueva(temario),
            icon: _leyendoTemario
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.video_call_outlined),
            label: const Text('Enviar una clase'),
          ),
        const SizedBox(height: 20),
        const Text(
          'Mis clases',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<ClaseDocente>>(
          future: _mias,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            final mias = s.data ?? const [];
            if (s.hasError || mias.isEmpty) {
              return Text(
                s.hasError
                    ? 'No se pudieron cargar tus clases.'
                    : 'Todavía no enviaste ninguna.',
                style: const TextStyle(color: ColoresApp.apagado),
              );
            }
            return Column(children: [for (final c in mias) _FilaMiClase(c)]);
          },
        ),
      ],
    );
  }
}

class _FilaMiClase extends StatelessWidget {
  final ClaseDocente clase;

  const _FilaMiClase(this.clase);

  @override
  Widget build(BuildContext context) {
    final color = switch (clase.estado) {
      EstadoClaseDocente.pendiente => ColoresApp.ambar,
      EstadoClaseDocente.aprobada => ColoresApp.celeste,
      EstadoClaseDocente.rechazada => ColoresApp.naranja,
    };
    return Card(
      child: ListTile(
        title: Text(clase.titulo),
        subtitle: Text(
          [
            [
              clase.cursoNombre,
              clase.temaTitulo,
            ].where((t) => t.isNotEmpty).join(' · '),
            if (clase.estado == EstadoClaseDocente.aprobada)
              '${clase.corazones} corazones',
            ?clase.motivo,
          ].join('\n'),
        ),
        isThreeLine: clase.motivo != null,
        trailing: Text(
          clase.estado.etiqueta,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Formulario de una clase: curso, tema, título y el enlace de YouTube
/// (puede ser "no listado"). Devuelve true si se envió.
class EnviarClaseDocentePage extends StatefulWidget {
  final String uid;
  final String nombre;
  final Curriculo curriculo;
  final RepositorioClasesDocente repositorio;

  const EnviarClaseDocentePage({
    super.key,
    required this.uid,
    required this.nombre,
    required this.curriculo,
    required this.repositorio,
  });

  @override
  State<EnviarClaseDocentePage> createState() => _EnviarClaseDocentePageState();
}

class _EnviarClaseDocentePageState extends State<EnviarClaseDocentePage> {
  final _titulo = TextEditingController();
  final _enlace = TextEditingController();
  Curso? _curso;
  Tema? _tema;
  bool _enviando = false;

  late final List<Curso> _cursos = [...widget.curriculo.cursos]
    ..sort((a, b) => a.orden.compareTo(b.orden));

  @override
  void dispose() {
    _titulo.dispose();
    _enlace.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final error = errorClaseDocente(
      temaId: _tema?.id,
      titulo: _titulo.text,
      enlace: _enlace.text,
    );
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _enviando = true);
    try {
      await widget.repositorio.enviar(
        docenteUid: widget.uid,
        docenteNombre: widget.nombre,
        temaId: _tema!.id,
        temaTitulo: _tema!.titulo,
        cursoNombre: _curso?.nombre ?? '',
        titulo: _titulo.text,
        videoId: idVideoYoutube(_enlace.text)!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar. Revisa tu conexión.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final curso = _curso;
    final temas = curso == null
        ? const <Tema>[]
        : widget.curriculo.temasDe(curso.id);
    final videoId = idVideoYoutube(_enlace.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar una clase')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const Text(
            'Sube tu video a YouTube (puede ser "no listado") y pega aquí el '
            'enlace. Lo revisamos antes de que lo vean los alumnos.',
            style: TextStyle(color: ColoresApp.apagado, height: 1.4),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<Curso>(
            initialValue: curso,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Curso'),
            items: [
              for (final c in _cursos)
                DropdownMenuItem(value: c, child: Text(c.nombre)),
            ],
            onChanged: (c) => setState(() {
              _curso = c;
              _tema = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Tema>(
            // Al cambiar de curso, el tema vuelve a vacío.
            key: ValueKey('tema-${curso?.id}'),
            initialValue: _tema,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tema'),
            items: [
              for (final t in temas)
                DropdownMenuItem(
                  value: t,
                  child: Text(
                    '${t.orden}. ${t.titulo}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: curso == null ? null : (t) => setState(() => _tema = t),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titulo,
            maxLength: maxTituloClase,
            decoration: const InputDecoration(
              labelText: 'Título de la clase',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _enlace,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Enlace de YouTube',
              hintText: 'https://youtu.be/…',
            ),
          ),
          if (videoId != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  miniaturaYoutube(videoId),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: ColoresApp.panel),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Enviar para revisión'),
          ),
        ],
      ),
    );
  }
}
