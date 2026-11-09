import 'package:flutter/material.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/video/reproductor_clase.dart';
import '../domain/clase_docente.dart';
import 'corazones_clases.dart';

/// Una clase de docente: el video dentro de la app, quién la hizo, el
/// corazón y la bandera para reportarla.
class ClaseDocentePage extends StatefulWidget {
  final ClaseDocente clase;
  final CorazonesClases corazones;
  final ConstructorReproductor reproductor;
  final VoidCallback onReportar;

  /// Abrir la página del docente (null: su nombre no se toca).
  final VoidCallback? onVerDocente;

  const ClaseDocentePage({
    super.key,
    required this.clase,
    required this.corazones,
    required this.reproductor,
    required this.onReportar,
    this.onVerDocente,
  });

  @override
  State<ClaseDocentePage> createState() => _ClaseDocentePageState();
}

class _ClaseDocentePageState extends State<ClaseDocentePage> {
  final _control = ControlClase();

  Future<void> _corazon() async {
    final ok = await widget.corazones.alternar(widget.clase.id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar tu corazón.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.clase;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clase de docente'),
        actions: [
          IconButton(
            tooltip: 'Reportar esta clase',
            onPressed: () {
              _control.pausar();
              widget.onReportar();
            },
            icon: const Icon(Icons.outlined_flag),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: widget.reproductor(
              videoId: c.videoId,
              inicio: 0,
              control: _control,
              alAvanzar: (_, _) {},
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.titulo,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: widget.onVerDocente,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 16,
                            color: ColoresApp.celeste,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              c.docenteNombre,
                              style: const TextStyle(
                                color: ColoresApp.celeste,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (widget.onVerDocente != null)
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: ColoresApp.celeste,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        c.cursoNombre,
                        c.temaTitulo,
                      ].where((t) => t.isNotEmpty).join(' · '),
                      style: const TextStyle(color: ColoresApp.apagado),
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: widget.corazones,
                builder: (context, _) => BotonCorazon(
                  dado: widget.corazones.dado(c.id),
                  cantidad: widget.corazones.cantidad(c.id),
                  onTap: _corazon,
                  tamano: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Esta clase la comparte un docente invitado y la revisó el '
            'equipo de AcademiApp. Si ves algo que no corresponde, '
            'repórtala con la bandera.',
            style: TextStyle(
              color: ColoresApp.tenue,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
