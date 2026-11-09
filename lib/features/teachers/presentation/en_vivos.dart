import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/animaciones.dart';
import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/formato_fecha.dart';
import '../domain/en_vivo.dart';

typedef AbrirEnlaceApp = Future<bool> Function(Uri enlace);

/// TikTok, Meet o YouTube se abren en su propia app.
Future<bool> abrirFueraDeLaApp(Uri enlace) =>
    launchUrl(enlace, mode: LaunchMode.externalApplication);

const colorEnVivo = Color(0xFFFF4D4F);

IconData iconoPlataforma(PlataformaEnVivo p) => switch (p) {
  PlataformaEnVivo.tiktok => Icons.music_note_rounded,
  PlataformaEnVivo.meet => Icons.videocam_rounded,
  PlataformaEnVivo.youtube => Icons.smart_display_rounded,
  PlataformaEnVivo.otra => Icons.link_rounded,
};

/// Vuelve a dibujar cada segundo (la cuenta regresiva). Si la pantalla no
/// se ve (otra pestaña), no redibuja.
class RelojEnVivos extends StatefulWidget {
  final DateTime Function() ahora;
  final Widget Function(BuildContext context, DateTime ahora) builder;

  const RelojEnVivos({super.key, required this.ahora, required this.builder});

  @override
  State<RelojEnVivos> createState() => _RelojEnVivosState();
}

class _RelojEnVivosState extends State<RelojEnVivos> {
  late final Timer _tic;

  @override
  void initState() {
    super.initState();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && TickerMode.valuesOf(context).enabled) setState(() {});
    });
  }

  @override
  void dispose() {
    _tic.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.ahora());
}

/// En vivos de los docentes en Inicio: cuenta regresiva y, a la hora,
/// "En vivo ahora · Unirme". Si no hay ninguno, no ocupa lugar.
class SeccionEnVivos extends StatefulWidget {
  final RepositorioEnVivos repositorio;
  final DateTime Function() ahora;
  final AbrirEnlaceApp abrirEnlace;
  final void Function(String docenteUid, String nombre)? onVerDocente;
  final void Function(EnVivo enVivo)? onReportar;

  const SeccionEnVivos({
    super.key,
    required this.repositorio,
    this.ahora = DateTime.now,
    this.abrirEnlace = abrirFueraDeLaApp,
    this.onVerDocente,
    this.onReportar,
  });

  @override
  State<SeccionEnVivos> createState() => _SeccionEnVivosState();
}

class _SeccionEnVivosState extends State<SeccionEnVivos> {
  List<EnVivo> _enVivos = const [];

  @override
  void initState() {
    super.initState();
    widget.repositorio
        .vigentes()
        .then((lista) {
          if (mounted && lista.isNotEmpty) setState(() => _enVivos = lista);
        })
        // Son un complemento: sin red, no aparecen.
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_enVivos.isEmpty) return const SizedBox.shrink();
    return RelojEnVivos(
      ahora: widget.ahora,
      builder: (context, ahora) {
        final lista = paraMostrar(_enVivos, ahora).take(3).toList();
        if (lista.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in lista)
                TarjetaEnVivo(
                  key: ValueKey(e.id),
                  enVivo: e,
                  ahora: ahora,
                  abrirEnlace: widget.abrirEnlace,
                  onVerDocente: widget.onVerDocente == null
                      ? null
                      : () =>
                            widget.onVerDocente!(e.docenteUid, e.docenteNombre),
                  onReportar: widget.onReportar == null
                      ? null
                      : () => widget.onReportar!(e),
                ),
            ],
          ),
        );
      },
    );
  }
}

class TarjetaEnVivo extends StatelessWidget {
  final EnVivo enVivo;
  final DateTime ahora;
  final AbrirEnlaceApp abrirEnlace;
  final VoidCallback? onVerDocente;
  final VoidCallback? onReportar;

  const TarjetaEnVivo({
    super.key,
    required this.enVivo,
    required this.ahora,
    required this.abrirEnlace,
    this.onVerDocente,
    this.onReportar,
  });

  Future<void> _unirme(BuildContext context) async {
    final uri = Uri.tryParse(enVivo.enlace);
    final abierto = uri != null && await abrirEnlace(uri);
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el en vivo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = enVivo;
    final enVivoAhora = e.momento(ahora) == MomentoEnVivo.enVivo;
    final acento = enVivoAhora ? colorEnVivo : ColoresApp.celeste;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: acento.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: acento.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (enVivoAhora)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorEnVivo,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '● EN VIVO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Text(
                  '${fechaCorta(e.inicio)} · ${horaCorta(e.inicio)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ColoresApp.apagado,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(iconoPlataforma(e.plataforma), size: 16, color: acento),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  e.plataforma.etiqueta,
                  style: TextStyle(fontSize: 12, color: acento),
                ),
              ),
              if (onReportar case final reportar?)
                IconButton(
                  tooltip: 'Reportar este en vivo',
                  visualDensity: VisualDensity.compact,
                  onPressed: reportar,
                  icon: const Icon(Icons.outlined_flag, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            e.titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: onVerDocente,
            child: Text(
              [e.docenteNombre, ?e.cursoNombre].join(' · '),
              style: TextStyle(
                color: onVerDocente == null
                    ? ColoresApp.apagado
                    : ColoresApp.celeste,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: enVivoAhora
                    ? Text(
                        'Termina a las ${horaCorta(e.fin)}',
                        style: const TextStyle(color: ColoresApp.apagado),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Empieza en',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColoresApp.apagado,
                            ),
                          ),
                          Text(
                            cuentaRegresiva(e.inicio.difference(ahora)),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
              ),
              if (e.sePuedeUnir(ahora))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: acento,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _unirme(context),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Unirme'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Próximos en vivos de un docente (en su página), con cuenta regresiva.
class EnVivosDelDocente extends StatelessWidget {
  final List<EnVivo> enVivos;
  final DateTime Function() ahora;
  final AbrirEnlaceApp abrirEnlace;

  const EnVivosDelDocente({
    super.key,
    required this.enVivos,
    this.ahora = DateTime.now,
    this.abrirEnlace = abrirFueraDeLaApp,
  });

  @override
  Widget build(BuildContext context) {
    if (enVivos.isEmpty) return const SizedBox.shrink();
    return RelojEnVivos(
      ahora: ahora,
      builder: (context, ahora) => EntradaDifuminada(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in paraMostrar(enVivos, ahora))
              TarjetaEnVivo(
                key: ValueKey(e.id),
                enVivo: e,
                ahora: ahora,
                abrirEnlace: abrirEnlace,
              ),
          ],
        ),
      ),
    );
  }
}
