import 'package:flutter/material.dart';

import '../../../core/presentation/animaciones.dart';
import '../../../core/presentation/carga_puma.dart';
import '../../../core/presentation/colores_app.dart';
import '../../academic/domain/entities/curriculo.dart';
import '../domain/clase_docente.dart';
import '../domain/en_vivo.dart';
import '../domain/solicitud_docente.dart';
import 'clases_del_docente.dart';
import 'mis_en_vivos.dart';

/// "¿Eres docente?": el formulario para pedir la cuenta o, si ya la pidió,
/// en qué va.
class SolicitudDocentePage extends StatefulWidget {
  final String uid;
  final String nombre;
  final String correo;
  final RepositorioDocentes repositorio;

  /// Para que el docente aprobado envíe sus clases (null: no se muestra).
  final RepositorioClasesDocente? clases;

  /// Temario donde elige el tema de cada clase (se lee al enviar una).
  final Future<Curriculo?> Function()? temario;

  /// Para que el docente aprobado programe sus en vivos.
  final RepositorioEnVivos? enVivos;

  const SolicitudDocentePage({
    super.key,
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.repositorio,
    this.clases,
    this.temario,
    this.enVivos,
  });

  @override
  State<SolicitudDocentePage> createState() => _SolicitudDocentePageState();
}

class _SolicitudDocentePageState extends State<SolicitudDocentePage> {
  late Future<SolicitudDocente?> _solicitud = widget.repositorio.miSolicitud(
    widget.uid,
  );

  final _celular = TextEditingController();
  final _cursos = TextEditingController();
  final _enlaces = [
    for (var i = 0; i < maxEnlacesDocente; i++) TextEditingController(),
  ];
  final _mensaje = TextEditingController();
  bool _enviando = false;

  /// Si no se aprobó, puede corregir y volver a enviarla.
  bool _reenviando = false;

  @override
  void dispose() {
    for (final c in [_celular, _cursos, ..._enlaces, _mensaje]) {
      c.dispose();
    }
    super.dispose();
  }

  void _avisar(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  void _reintentar() {
    setState(() {
      _solicitud = widget.repositorio.miSolicitud(widget.uid);
    });
  }

  void _corregir(SolicitudDocente anterior) {
    _celular.text = anterior.celular;
    _cursos.text = anterior.cursos;
    for (final (i, c) in _enlaces.indexed) {
      c.text = i < anterior.enlaces.length ? anterior.enlaces[i] : '';
    }
    _mensaje.text = anterior.mensaje;
    setState(() => _reenviando = true);
  }

  Future<void> _enviar() async {
    final enlaces = enlacesLimpios([for (final c in _enlaces) c.text]);
    final error = errorSolicitudDocente(
      celular: _celular.text,
      cursos: _cursos.text,
      enlaces: enlaces,
      mensaje: _mensaje.text,
    );
    if (error != null) {
      _avisar(error);
      return;
    }

    setState(() => _enviando = true);
    try {
      await widget.repositorio.solicitar(
        uid: widget.uid,
        nombre: widget.nombre,
        correo: widget.correo,
        celular: _celular.text,
        cursos: _cursos.text,
        enlaces: enlaces,
        mensaje: _mensaje.text,
      );
      if (!mounted) return;
      _avisar('Solicitud enviada. Te avisaremos aquí.');
      setState(() {
        _reenviando = false;
        _solicitud = widget.repositorio.miSolicitud(widget.uid);
      });
    } catch (_) {
      if (mounted) _avisar('No se pudo enviar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta de docente')),
      body: FutureBuilder<SolicitudDocente?>(
        future: _solicitud,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CargaPuma.compacta());
          }
          if (s.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reintentar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final solicitud = s.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: enCascada([
              if (solicitud == null || _reenviando)
                ..._formulario(solicitud)
              else ...[
                _estado(solicitud),
                if (solicitud.estado == EstadoSolicitudDocente.aprobada)
                  if (widget.clases case final clases?)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: ClasesDelDocente(
                        uid: widget.uid,
                        nombre: widget.nombre,
                        repositorio: clases,
                        temario: widget.temario,
                      ),
                    ),
                if (solicitud.estado == EstadoSolicitudDocente.aprobada)
                  if (widget.enVivos case final enVivos?)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: MisEnVivos(
                        uid: widget.uid,
                        nombre: widget.nombre,
                        repositorio: enVivos,
                      ),
                    ),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _estado(SolicitudDocente s) {
    final (icono, color, titulo, detalle) = switch (s.estado) {
      EstadoSolicitudDocente.pendiente => (
        Icons.hourglass_top_rounded,
        ColoresApp.ambar,
        'Tu solicitud está en revisión',
        'Revisamos tu canal o tus redes. Te avisaremos aquí cuando esté '
            'lista.',
      ),
      EstadoSolicitudDocente.aprobada => (
        Icons.verified_outlined,
        ColoresApp.celeste,
        '¡Ya eres docente en AcademiApp!',
        'Envía tus clases y programa tus en vivos desde aquí. Cada uno '
            'pasa por revisión antes de que lo vean los alumnos.',
      ),
      EstadoSolicitudDocente.rechazada => (
        Icons.info_outline,
        ColoresApp.naranja,
        'Tu solicitud no fue aprobada',
        s.motivo ?? 'Puedes corregirla y volver a enviarla.',
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              style: const TextStyle(color: ColoresApp.apagado, height: 1.4),
            ),
            const SizedBox(height: 16),
            _Dato('Cursos', s.cursos),
            for (final e in s.enlaces) _Dato('Enlace', e),
            if (s.estado == EstadoSolicitudDocente.rechazada) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _corregir(s),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corregir y volver a enviar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _formulario(SolicitudDocente? anterior) => [
    const Text(
      '¿Eres docente?',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 6),
    const Text(
      'Comparte tus clases con los alumnos de AcademiApp; no necesitas estar '
      'matriculado. Revisamos cada solicitud: déjanos tu celular y tu canal '
      'de YouTube o una red social donde se vea tu trabajo.',
      style: TextStyle(color: ColoresApp.apagado, height: 1.4),
    ),
    if (anterior?.motivo case final motivo?) ...[
      const SizedBox(height: 12),
      Text(
        'Motivo anterior: $motivo',
        style: const TextStyle(color: ColoresApp.naranja),
      ),
    ],
    const SizedBox(height: 20),
    TextField(
      controller: _celular,
      keyboardType: TextInputType.phone,
      maxLength: 15,
      decoration: const InputDecoration(
        labelText: 'Tu celular (WhatsApp)',
        hintText: '987 654 321',
        helperText: 'Para verificar que eres docente. Solo lo ve el equipo.',
        counterText: '',
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _cursos,
      maxLength: maxCursosDocente,
      decoration: const InputDecoration(
        labelText: 'Curso o cursos que enseñas',
        hintText: 'Historia del Perú, Literatura',
        counterText: '',
      ),
    ),
    const SizedBox(height: 12),
    for (final (i, c) in _enlaces.indexed) ...[
      TextField(
        controller: c,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: i == 0
              ? 'Tu canal de YouTube o red social'
              : 'Otro enlace (opcional)',
          hintText: 'https://…',
        ),
      ),
      const SizedBox(height: 12),
    ],
    TextField(
      controller: _mensaje,
      minLines: 3,
      maxLines: 6,
      maxLength: maxMensajeDocente,
      decoration: const InputDecoration(
        labelText: 'Cuéntanos de ti',
        hintText: 'Dónde enseñas, desde cuándo, qué temas te gustan…',
        alignLabelWithHint: true,
      ),
    ),
    const SizedBox(height: 8),
    FilledButton.icon(
      onPressed: _enviando ? null : _enviar,
      icon: _enviando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_outlined),
      label: const Text('Enviar solicitud'),
    ),
  ];
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Dato(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              etiqueta,
              style: const TextStyle(color: ColoresApp.tenue, fontSize: 13),
            ),
          ),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
