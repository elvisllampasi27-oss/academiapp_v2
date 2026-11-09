import 'package:flutter/material.dart';

import '../../../core/presentation/animaciones.dart';
import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/video/reproductor_clase.dart';
import '../../../core/presentation/video/reproductor_youtube.dart';
import '../domain/clase_docente.dart';
import 'clase_docente_page.dart';
import 'corazones_clases.dart';

/// "Clases de docentes" de un tema (o de un docente, en su página), las
/// más queridas primero. Si no hay ninguna (o no se pudieron leer) no
/// ocupa lugar.
class SeccionClasesDocentes extends StatefulWidget {
  final RepositorioClasesDocente repositorio;

  /// Las del tema o, si se da [docenteUid], las de ese docente.
  final String? temaId;
  final String? docenteUid;
  final String titulo;

  /// El alumno que mira (sus corazones).
  final String uid;

  /// Antes de abrir una (por ejemplo, pausar la clase del tema).
  final VoidCallback? alAbrir;

  /// Reportar una clase (lo compone quien abre la pantalla).
  final void Function(ClaseDocente clase) onReportar;

  /// Abrir la página del docente.
  final void Function(String docenteUid, String nombre)? onVerDocente;

  /// Inyectable en pruebas; por defecto YouTube dentro de la app.
  final ConstructorReproductor reproductor;

  const SeccionClasesDocentes({
    super.key,
    required this.repositorio,
    required this.uid,
    required this.onReportar,
    this.temaId,
    this.docenteUid,
    this.titulo = 'Clases de docentes',
    this.onVerDocente,
    this.alAbrir,
    this.reproductor = reproductorYoutube,
  });

  @override
  State<SeccionClasesDocentes> createState() => _SeccionClasesDocentesState();
}

class _SeccionClasesDocentesState extends State<SeccionClasesDocentes> {
  List<ClaseDocente> _clases = const [];
  CorazonesClases? _corazones;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final docente = widget.docenteUid;
      final clases = docente != null
          ? await widget.repositorio.deDocente(docente)
          : await widget.repositorio.delTema(widget.temaId ?? '');
      if (clases.isEmpty) return;
      // Sin sus corazones igual se ven las clases.
      final mios = await widget.repositorio
          .conMiCorazon(widget.uid, [for (final c in clases) c.id])
          .catchError((Object _) => <String>{});
      if (!mounted) return;
      setState(() {
        _clases = clases;
        _corazones = CorazonesClases(
          repositorio: widget.repositorio,
          uid: widget.uid,
          clases: clases,
          mios: mios,
        );
      });
    } catch (_) {
      // Son un complemento: sin red, la sección no aparece.
    }
  }

  @override
  void dispose() {
    _corazones?.dispose();
    super.dispose();
  }

  Future<void> _alternar(String claseId) async {
    final ok = await _corazones!.alternar(claseId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar tu corazón.')),
      );
    }
  }

  void _abrir(ClaseDocente clase) {
    widget.alAbrir?.call();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClaseDocentePage(
          clase: clase,
          corazones: _corazones!,
          reproductor: widget.reproductor,
          onReportar: () => widget.onReportar(clase),
          onVerDocente: widget.onVerDocente == null
              ? null
              : () =>
                    widget.onVerDocente!(clase.docenteUid, clase.docenteNombre),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corazones = _corazones;
    if (corazones == null || _clases.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EntradaDifuminada(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 20,
                    color: ColoresApp.celeste,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListenableBuilder(
            listenable: corazones,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in _clases.indexed)
                  FilaEntrante(
                    key: ValueKey(c.id),
                    indice: i,
                    child: _TarjetaClase(
                      clase: c,
                      dado: corazones.dado(c.id),
                      cantidad: corazones.cantidad(c.id),
                      onAbrir: () => _abrir(c),
                      onCorazon: () => _alternar(c.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaClase extends StatelessWidget {
  final ClaseDocente clase;
  final bool dado;
  final int cantidad;
  final VoidCallback onAbrir;
  final VoidCallback onCorazon;

  const _TarjetaClase({
    required this.clase,
    required this.dado,
    required this.cantidad,
    required this.onAbrir,
    required this.onCorazon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 112,
                  height: 63,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        clase.miniatura,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: ColoresApp.panel),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white70,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clase.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clase.docenteNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ColoresApp.apagado,
                      ),
                    ),
                  ],
                ),
              ),
              BotonCorazon(dado: dado, cantidad: cantidad, onTap: onCorazon),
            ],
          ),
        ),
      ),
    );
  }
}
