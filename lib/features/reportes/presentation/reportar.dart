import 'package:flutter/material.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/formato_fecha.dart';
import '../domain/reporte.dart';
import '../../../core/presentation/animaciones.dart';
import '../../../core/presentation/carga_puma.dart';

/// Quién reporta (lo pone la app, no el estudiante).
class AutorReporte {
  final String uid;
  final String nombre;
  final String correo;

  const AutorReporte({
    required this.uid,
    required this.nombre,
    required this.correo,
  });
}

/// Hoja para contar el problema. Devuelve true si se envió.
Future<bool> mostrarReportar(
  BuildContext context, {
  required RepositorioReportes repositorio,
  required AutorReporte autor,
  required TipoReporte tipo,
  required ContextoReporte contexto,
}) async {
  final enviado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HojaReportar(
      repositorio: repositorio,
      autor: autor,
      tipo: tipo,
      contexto: contexto,
    ),
  );
  if (enviado == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Gracias. Lo revisaremos y verás la respuesta en tu Perfil.',
        ),
      ),
    );
  }
  return enviado ?? false;
}

class _HojaReportar extends StatefulWidget {
  final RepositorioReportes repositorio;
  final AutorReporte autor;
  final TipoReporte tipo;
  final ContextoReporte contexto;

  const _HojaReportar({
    required this.repositorio,
    required this.autor,
    required this.tipo,
    required this.contexto,
  });

  @override
  State<_HojaReportar> createState() => _HojaReportarState();
}

class _HojaReportarState extends State<_HojaReportar> {
  final _mensaje = TextEditingController();
  late TipoReporte _tipo = widget.tipo;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _mensaje.text.trim();
    if (texto.length < largoMinimoReporte) {
      setState(() => _error = 'Cuéntanos un poco más qué pasó.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await widget.repositorio.enviar(
        uid: widget.autor.uid,
        nombre: widget.autor.nombre,
        correo: widget.autor.correo,
        tipo: _tipo,
        mensaje: texto,
        contexto: widget.contexto,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = 'No se pudo enviar. Revisa tu conexión.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Reportar un problema',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            widget.contexto.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ColoresApp.apagado),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in TipoReporte.values)
                ChoiceChip(
                  label: Text(t.etiqueta),
                  selected: _tipo == t,
                  onSelected: (_) => setState(() => _tipo = t),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _mensaje,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: largoMaximoReporte,
            decoration: const InputDecoration(
              hintText:
                  'Ej.: la respuesta correcta no está entre las opciones.',
            ),
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(e, style: const TextStyle(color: ColoresApp.naranja)),
            ),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar reporte'),
          ),
        ],
      ),
    );
  }
}

/// Los reportes del estudiante con su estado y la respuesta del equipo.
class MisReportesPage extends StatefulWidget {
  final RepositorioReportes repositorio;
  final String uid;

  const MisReportesPage({
    super.key,
    required this.repositorio,
    required this.uid,
  });

  @override
  State<MisReportesPage> createState() => _MisReportesPageState();
}

class _MisReportesPageState extends State<MisReportesPage> {
  late final Future<List<Reporte>> _reportes = widget.repositorio.mios(
    widget.uid,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes')),
      body: FutureBuilder<List<Reporte>>(
        future: _reportes,
        builder: (context, s) {
          if (s.hasError) {
            return const Center(child: Text('No se pudieron cargar.'));
          }
          final lista = s.data;
          if (lista == null) {
            return const Center(child: CargaPuma.compacta());
          }
          if (lista.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no reportaste nada.',
                style: TextStyle(color: ColoresApp.apagado),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final (i, r) in lista.indexed)
                FilaEntrante(
                  indice: i,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.contexto.titulo.isEmpty
                                      ? r.tipo.etiqueta
                                      : r.contexto.titulo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                r.estado.etiqueta,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: switch (r.estado) {
                                    EstadoReporte.nuevo => ColoresApp.apagado,
                                    EstadoReporte.enRevision =>
                                      ColoresApp.ambar,
                                    EstadoReporte.resuelto =>
                                      ColoresApp.celeste,
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r.tipo.etiqueta} · ${fechaCorta(r.creadoEn)}',
                            style: const TextStyle(
                              color: ColoresApp.apagado,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(r.mensaje),
                          if (r.respuesta case final respuesta?) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ColoresApp.celeste.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('Respuesta: $respuesta'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
