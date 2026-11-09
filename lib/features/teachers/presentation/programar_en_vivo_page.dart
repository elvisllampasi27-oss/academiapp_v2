import 'package:flutter/material.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/formato_fecha.dart';
import '../domain/en_vivo.dart';
import 'en_vivos.dart';

String _ejemploEnlace(PlataformaEnVivo p) => switch (p) {
  PlataformaEnVivo.tiktok => 'https://www.tiktok.com/@tuusuario/live',
  PlataformaEnVivo.meet => 'https://meet.google.com/abc-defg-hij',
  PlataformaEnVivo.youtube => 'https://youtube.com/live/…',
  PlataformaEnVivo.otra => 'https://…',
};

/// El docente programa un en vivo: plataforma, enlace, fecha, hora y
/// duración. Lo ven los alumnos cuando el administrador lo aprueba.
/// Devuelve true si se envió.
class ProgramarEnVivoPage extends StatefulWidget {
  final String uid;
  final String nombre;
  final RepositorioEnVivos repositorio;
  final DateTime Function() ahora;

  const ProgramarEnVivoPage({
    super.key,
    required this.uid,
    required this.nombre,
    required this.repositorio,
    this.ahora = DateTime.now,
  });

  @override
  State<ProgramarEnVivoPage> createState() => _ProgramarEnVivoPageState();
}

class _ProgramarEnVivoPageState extends State<ProgramarEnVivoPage> {
  final _titulo = TextEditingController();
  final _enlace = TextEditingController();
  final _curso = TextEditingController();
  PlataformaEnVivo _plataforma = PlataformaEnVivo.tiktok;

  /// Por defecto, mañana a las 7:00 p. m.
  late DateTime _fecha = () {
    final m = widget.ahora().add(const Duration(days: 1));
    return DateTime(m.year, m.month, m.day);
  }();
  TimeOfDay _hora = const TimeOfDay(hour: 19, minute: 0);
  int _duracion = 60;
  bool _enviando = false;

  DateTime get _inicio =>
      DateTime(_fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);

  @override
  void dispose() {
    for (final c in [_titulo, _enlace, _curso]) {
      c.dispose();
    }
    super.dispose();
  }

  void _avisar(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _elegirFecha() async {
    final hoy = widget.ahora();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: diasMaximosEnVivo)),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(context: context, initialTime: _hora);
    if (elegida != null) setState(() => _hora = elegida);
  }

  Future<void> _enviar() async {
    final error = errorEnVivo(
      titulo: _titulo.text,
      plataforma: _plataforma,
      enlace: _enlace.text,
      inicio: _inicio,
      ahora: widget.ahora(),
    );
    if (error != null) {
      _avisar(error);
      return;
    }

    setState(() => _enviando = true);
    try {
      await widget.repositorio.programar(
        docenteUid: widget.uid,
        docenteNombre: widget.nombre,
        titulo: _titulo.text,
        plataforma: _plataforma,
        enlace: _enlace.text,
        inicio: _inicio,
        duracionMinutos: _duracion,
        cursoNombre: _curso.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      _avisar('No se pudo enviar. Revisa tu conexión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programar un en vivo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const Text(
            'Los alumnos lo verán en su Inicio con una cuenta regresiva y, a '
            'la hora, el botón para unirse. Lo revisamos antes de publicarlo.',
            style: TextStyle(color: ColoresApp.apagado, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titulo,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Repaso de los incas para el examen',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          const Text('¿Dónde?', style: TextStyle(color: ColoresApp.apagado)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in PlataformaEnVivo.values)
                ChoiceChip(
                  avatar: Icon(iconoPlataforma(p), size: 18),
                  label: Text(p.etiqueta),
                  selected: _plataforma == p,
                  onSelected: (_) => setState(() => _plataforma = p),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _enlace,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Enlace del en vivo',
              hintText: _ejemploEnlace(_plataforma),
            ),
          ),
          if (_plataforma == PlataformaEnVivo.meet) ...[
            const SizedBox(height: 8),
            const Text(
              'En Meet, tú admites a cada persona que pide entrar. No '
              'compartas datos personales ni pidas los de los alumnos.',
              style: TextStyle(
                color: ColoresApp.ambar,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(fechaCorta(_fecha)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _elegirHora,
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text(horaCorta(_inicio)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _duracion,
            decoration: const InputDecoration(labelText: 'Duración'),
            items: [
              for (final m in duracionesEnVivo)
                DropdownMenuItem(
                  value: m,
                  child: Text(
                    m < 60
                        ? '$m minutos'
                        : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}',
                  ),
                ),
            ],
            onChanged: (m) => setState(() => _duracion = m ?? _duracion),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _curso,
            decoration: const InputDecoration(
              labelText: 'Curso (opcional)',
              hintText: 'Historia del Perú',
            ),
          ),
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
