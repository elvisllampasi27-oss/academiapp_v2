import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/formato_fecha.dart';
import '../../../core/presentation/video/reproductor_clase.dart';
import '../../../core/presentation/video/reproductor_youtube.dart';
import '../domain/seminario.dart';

Future<bool> _abrirEnYoutube(Uri enlace) =>
    launchUrl(enlace, mode: LaunchMode.externalApplication);

/// Seminarios: el próximo en vivo (se ve y se pregunta en YouTube) y los
/// grabados (se ven dentro de la app).
class SeminariosPage extends StatefulWidget {
  final RepositorioSeminarios repositorio;
  final DateTime Function() ahora;
  final Future<bool> Function(Uri enlace) abrirEnlace;
  final ConstructorReproductor reproductor;

  const SeminariosPage({
    super.key,
    required this.repositorio,
    this.ahora = DateTime.now,
    this.abrirEnlace = _abrirEnYoutube,
    this.reproductor = reproductorYoutube,
  });

  @override
  State<SeminariosPage> createState() => _SeminariosPageState();
}

class _SeminariosPageState extends State<SeminariosPage> {
  late Future<List<Seminario>> _seminarios = widget.repositorio.listar();

  Future<void> _abrirVivo(Seminario seminario) async {
    final abierto = await widget.abrirEnlace(seminario.enlace);
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir YouTube.')),
      );
    }
  }

  void _verGrabado(Seminario seminario) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SeminarioGrabadoPage(
          seminario: seminario,
          reproductor: widget.reproductor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seminarios')),
      body: FutureBuilder<List<Seminario>>(
        future: _seminarios,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _seminarios = widget.repositorio.listar();
                }),
                child: const Text('Reintentar'),
              ),
            );
          }

          final ahora = widget.ahora();
          final todos = snapshot.data!;
          final porVenir =
              todos
                  .where((s) => s.estado(ahora) != EstadoSeminario.grabado)
                  .toList()
                ..sort((a, b) => a.fecha.compareTo(b.fecha));
          final grabados =
              todos
                  .where((s) => s.estado(ahora) == EstadoSeminario.grabado)
                  .toList()
                ..sort((a, b) => b.fecha.compareTo(a.fecha));
          final proximo = porVenir.firstOrNull;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const Text(
                'Repasos complementarios. No reemplazan tus temas del día.',
                style: TextStyle(color: ColoresApp.apagado),
              ),
              const SizedBox(height: 24),
              const _Rotulo('PRÓXIMO EN VIVO'),
              if (proximo == null)
                const Text(
                  'No hay seminarios programados por ahora.',
                  style: TextStyle(color: ColoresApp.apagado),
                )
              else
                _TarjetaVivo(
                  seminario: proximo,
                  enVivo: proximo.estado(ahora) == EstadoSeminario.enVivo,
                  alAbrir: () => _abrirVivo(proximo),
                ),
              const SizedBox(height: 28),
              const _Rotulo('GRABADOS'),
              if (grabados.isEmpty)
                const Text(
                  'Aquí aparecerán los seminarios ya transmitidos.',
                  style: TextStyle(color: ColoresApp.apagado),
                )
              else
                for (final s in grabados)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(s.titulo),
                      subtitle: Text(
                        [
                          ?s.curso,
                          fechaCorta(s.fecha),
                          '${s.duracionMinutos} min',
                        ].join(' · '),
                      ),
                      onTap: () => _verGrabado(s),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  final String texto;

  const _Rotulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: ColoresApp.apagado,
        ),
      ),
    );
  }
}

class _TarjetaVivo extends StatelessWidget {
  final Seminario seminario;
  final bool enVivo;
  final VoidCallback alAbrir;

  const _TarjetaVivo({
    required this.seminario,
    required this.enVivo,
    required this.alAbrir,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (enVivo)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ColoresApp.naranja.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'EN VIVO AHORA',
                  style: TextStyle(
                    color: ColoresApp.naranja,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              seminario.titulo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              [
                ?seminario.curso,
                fechaCorta(seminario.fecha),
                horaCorta(seminario.fecha),
              ].join(' · '),
              style: const TextStyle(color: ColoresApp.apagado),
            ),
            const SizedBox(height: 4),
            const Text(
              'Las preguntas se hacen en el chat de YouTube.',
              style: TextStyle(color: ColoresApp.apagado, fontSize: 13),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: alAbrir,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir en YouTube'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seminario grabado: se ve dentro de la app.
class _SeminarioGrabadoPage extends StatefulWidget {
  final Seminario seminario;
  final ConstructorReproductor reproductor;

  const _SeminarioGrabadoPage({
    required this.seminario,
    required this.reproductor,
  });

  @override
  State<_SeminarioGrabadoPage> createState() => _SeminarioGrabadoPageState();
}

class _SeminarioGrabadoPageState extends State<_SeminarioGrabadoPage> {
  final _control = ControlClase();

  @override
  Widget build(BuildContext context) {
    final s = widget.seminario;

    return Scaffold(
      appBar: AppBar(title: Text(s.curso ?? 'Seminario')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: widget.reproductor(
              videoId: s.videoId,
              inicio: 0,
              control: _control,
              alAvanzar: (_, _) {},
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.titulo,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Grabado el ${fechaCorta(s.fecha).toLowerCase()}',
            style: const TextStyle(color: ColoresApp.apagado),
          ),
        ],
      ),
    );
  }
}
