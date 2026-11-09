import 'package:flutter/material.dart';

import '../../../core/presentation/animaciones.dart';
import '../../../core/presentation/carga_puma.dart';
import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/video/reproductor_clase.dart';
import '../../../core/presentation/video/reproductor_youtube.dart';
import '../domain/clase_docente.dart';
import '../domain/en_vivo.dart';
import '../domain/solicitud_docente.dart';
import 'en_vivos.dart';
import 'seccion_clases_docentes.dart';

/// Ícono de una red según su dominio.
IconData iconoRed(String enlace) {
  final host = Uri.tryParse(enlace)?.host.toLowerCase() ?? '';
  if (host.contains('youtu')) return Icons.smart_display_rounded;
  if (host.contains('tiktok')) return Icons.music_note_rounded;
  if (host.contains('facebook') || host.contains('fb.')) {
    return Icons.facebook;
  }
  if (host.contains('instagram')) return Icons.camera_alt_outlined;
  return Icons.link_rounded;
}

/// Nombre corto de la red ("YouTube", "TikTok"…) o el dominio.
String nombreRed(String enlace) {
  final host = (Uri.tryParse(enlace)?.host.toLowerCase() ?? enlace)
      .replaceFirst('www.', '')
      .replaceFirst('m.', '');
  if (host.contains('youtu')) return 'YouTube';
  if (host.contains('tiktok')) return 'TikTok';
  if (host.contains('facebook') || host.startsWith('fb.')) return 'Facebook';
  if (host.contains('instagram')) return 'Instagram';
  return host;
}

/// Página de un docente: sus redes, sus próximos en vivos y sus clases.
class PerfilDocentePage extends StatefulWidget {
  final String docenteUid;

  /// Se muestra mientras se lee su perfil.
  final String nombre;

  /// El alumno que mira (sus corazones).
  final String uid;
  final RepositorioDocentes docentes;
  final RepositorioClasesDocente clases;
  final RepositorioEnVivos enVivos;
  final void Function(ClaseDocente clase) onReportarClase;
  final AbrirEnlaceApp abrirEnlace;
  final ConstructorReproductor reproductor;
  final DateTime Function() ahora;

  const PerfilDocentePage({
    super.key,
    required this.docenteUid,
    required this.nombre,
    required this.uid,
    required this.docentes,
    required this.clases,
    required this.enVivos,
    required this.onReportarClase,
    this.abrirEnlace = abrirFueraDeLaApp,
    this.reproductor = reproductorYoutube,
    this.ahora = DateTime.now,
  });

  @override
  State<PerfilDocentePage> createState() => _PerfilDocentePageState();
}

class _PerfilDocentePageState extends State<PerfilDocentePage> {
  late final Future<PerfilDocente?> _perfil = widget.docentes.perfil(
    widget.docenteUid,
  );
  late final Future<List<EnVivo>> _enVivos = widget.enVivos
      .delDocente(widget.docenteUid)
      .catchError((Object _) => const <EnVivo>[]);

  Future<void> _abrir(String enlace) async {
    final uri = Uri.tryParse(enlace);
    final abierto = uri != null && await widget.abrirEnlace(uri);
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Docente')),
      body: FutureBuilder<PerfilDocente?>(
        future: _perfil,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CargaPuma.compacta());
          }
          final perfil = s.data;
          if (perfil == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Este docente ya no tiene su página activa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresApp.apagado),
                ),
              ),
            );
          }
          final nombre = perfil.nombre.trim().isEmpty
              ? widget.nombre
              : perfil.nombre;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              EntradaDifuminada(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: ColoresApp.celeste.withValues(
                        alpha: 0.16,
                      ),
                      child: Text(
                        nombre.trim().isEmpty
                            ? '?'
                            : nombre.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.celeste,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (perfil.cursos.isNotEmpty)
                            Text(
                              perfil.cursos,
                              style: const TextStyle(color: ColoresApp.apagado),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (perfil.enlaces.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in perfil.enlaces)
                      ActionChip(
                        avatar: Icon(iconoRed(e), size: 18),
                        label: Text(nombreRed(e)),
                        onPressed: () => _abrir(e),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FutureBuilder<List<EnVivo>>(
                future: _enVivos,
                builder: (context, s) => EnVivosDelDocente(
                  enVivos: s.data ?? const [],
                  ahora: widget.ahora,
                  abrirEnlace: widget.abrirEnlace,
                ),
              ),
              SeccionClasesDocentes(
                repositorio: widget.clases,
                docenteUid: widget.docenteUid,
                titulo: 'Sus clases',
                uid: widget.uid,
                onReportar: widget.onReportarClase,
                reproductor: widget.reproductor,
              ),
            ],
          );
        },
      ),
    );
  }
}
