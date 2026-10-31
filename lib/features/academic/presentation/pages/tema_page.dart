import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/menu_gota.dart';
import '../../domain/entities/contenido.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/material_tema.dart';
import '../../domain/entities/progreso_clase.dart';
import '../../domain/entities/recurso.dart';
import '../../domain/entities/tema.dart';
import '../../domain/repositories/repositorio_progreso_clase.dart';
import '../../domain/services/obtener_material_tema_service.dart';
import '../../domain/services/seguimiento_clase.dart';
import '../utils/enlace_recurso.dart';
import '../widgets/reproductor_clase.dart';
import '../widgets/reproductor_youtube.dart';

typedef AbrirEnlace = Future<bool> Function(Uri enlace);

Future<bool> _abrirEnNavegador(Uri enlace) =>
    launchUrl(enlace, mode: LaunchMode.externalApplication);

/// Pantalla del tema: la clase (video dentro de la app), qué se aprende,
/// el quiz (se activa al terminar la clase) y el botón "+" con las dudas y
/// la separata.
class TemaPage extends StatefulWidget {
  final Tema tema;
  final Curso? curso;
  final String versionId;
  final String usuarioId;
  final ObtenerMaterialTemaService service;
  final RepositorioProgresoClase repositorioProgreso;

  /// Inyectable para pruebas; por defecto YouTube dentro de la app.
  final ConstructorReproductor reproductor;

  /// Inyectable para pruebas; por defecto abre en el navegador/app externa.
  final AbrirEnlace abrirEnlace;

  /// Bloque del quiz. Lo compone quien abre la pantalla (así el módulo
  /// académico no depende del de evaluación). [habilitada] es false mientras
  /// la clase no se haya visto.
  final Widget Function(bool habilitada)? practica;

  /// Panel de dudas con el tutor (si está disponible).
  final Widget Function(VoidCallback cerrar)? dudas;

  const TemaPage({
    super.key,
    required this.tema,
    required this.curso,
    required this.versionId,
    required this.usuarioId,
    required this.service,
    required this.repositorioProgreso,
    this.reproductor = reproductorYoutube,
    this.abrirEnlace = _abrirEnNavegador,
    this.practica,
    this.dudas,
  });

  @override
  State<TemaPage> createState() => _TemaPageState();
}

class _TemaPageState extends State<TemaPage> {
  final _control = ControlClase();
  final _avance = ValueNotifier<AvanceClase>((
    fraccion: 0,
    duracion: 0,
    saltadoDesde: null,
  ));

  MaterialTema? _material;
  bool _cargando = true;
  bool _error = false;

  SeguimientoClase _seguimiento = SeguimientoClase();
  int _decenaGuardada = 0;
  double _vistoGuardado = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _reintentar() {
    setState(() {
      _cargando = true;
      _error = false;
    });
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final progreso = _obtenerProgreso();
      final material = await widget.service.obtener(
        temaId: widget.tema.id,
        versionId: widget.versionId,
      );
      final seguimiento = SeguimientoClase.desde(await progreso);

      if (!mounted) return;

      setState(() {
        _material = material;
        _seguimiento = seguimiento;
        _decenaGuardada = (seguimiento.fraccion * 10).floor();
        _vistoGuardado = seguimiento.visto;
        _avance.value = _leerAvance(seguimiento);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  /// El progreso es secundario: si falla, la clase empieza desde cero.
  Future<ProgresoClase?> _obtenerProgreso() async {
    try {
      return await widget.repositorioProgreso.obtener(
        usuarioId: widget.usuarioId,
        versionId: widget.versionId,
        temaId: widget.tema.id,
      );
    } catch (_) {
      return null;
    }
  }

  void _alAvanzar(double posicion, double duracion) {
    if (!mounted) return;

    final completadaAntes = _seguimiento.completada;
    final avanzo = _seguimiento.registrar(
      posicion: posicion,
      duracion: duracion,
    );

    _avance.value = _leerAvance(_seguimiento);

    if (!avanzo) return;

    if (_seguimiento.completada && !completadaAntes) {
      _guardar();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clase vista. Ya puedes hacer el quiz.')),
      );
      return;
    }

    // Se guarda cada 10 % para no escribir a cada segundo.
    if ((_seguimiento.fraccion * 10).floor() > _decenaGuardada) _guardar();
  }

  static AvanceClase _leerAvance(SeguimientoClase s) => (
    fraccion: s.fraccion,
    duracion: s.duracion,
    saltadoDesde: s.saltadoDesde,
  );

  void _guardar() {
    _decenaGuardada = (_seguimiento.fraccion * 10).floor();
    _vistoGuardado = _seguimiento.visto;

    unawaited(
      widget.repositorioProgreso
          .guardar(
            usuarioId: widget.usuarioId,
            progreso: _seguimiento.aProgreso(
              temaId: widget.tema.id,
              versionId: widget.versionId,
            ),
          )
          .catchError((Object _) {}),
    );
  }

  Future<void> _abrir(Recurso recurso) async {
    final enlace = enlaceDeRecurso(recurso);
    final abierto = enlace != null && await widget.abrirEnlace(enlace);

    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir este material.')),
      );
    }
  }

  Future<void> _abrirDudas() {
    _control.pausar();

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar dudas',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (contexto, _, _) => _VentanaDudas(
        child: widget.dudas!(() => Navigator.of(contexto).pop()),
      ),
      transitionBuilder: (_, animacion, _, hijo) => FadeTransition(
        opacity: animacion,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animacion, curve: Curves.easeOut)),
          child: hijo,
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_seguimiento.visto > _vistoGuardado + 1) _guardar();
    _avance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = widget.tema;
    final material = _material;
    final organizado = material == null ? null : _Organizado.de(material);

    final acciones = [
      if (organizado != null && widget.dudas != null)
        AccionGota(
          etiqueta: 'Resolver dudas',
          icono: Icons.chat_bubble_outline,
          alPresionar: _abrirDudas,
        ),
      if (organizado?.separata case final separata?)
        AccionGota(
          etiqueta: 'Separata',
          icono: Icons.menu_book_outlined,
          alPresionar: () => _abrir(separata),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [?widget.curso?.nombre, 'Tema ${tema.orden}'].join(' · '),
              style: const TextStyle(fontSize: 13, color: ColoresApp.apagado),
            ),
            Text(
              tema.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Column (no ListView) para que el video no se destruya al
          // desplazarse fuera de la pantalla.
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _cuerpo(organizado),
            ),
          ),
          if (acciones.isNotEmpty)
            Positioned.fill(child: MenuGota(acciones: acciones)),
        ],
      ),
    );
  }

  List<Widget> _cuerpo(_Organizado? organizado) {
    if (_cargando) {
      return const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ];
    }

    if (_error || organizado == null) {
      return [
        const SizedBox(height: 24),
        const Text('No se pudo cargar el material del tema.'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ];
    }

    final material = organizado.material;
    final videoId = organizado.videoId;
    final quizHabilitado = videoId == null || _seguimiento.completada;

    return [
      if (videoId != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: widget.reproductor(
            videoId: videoId,
            inicio: _seguimiento.continuarDesde,
            control: _control,
            alAvanzar: _alAvanzar,
          ),
        ),
        const SizedBox(height: 12),
        _AvanceClase(
          titulo: organizado.clase!.titulo,
          avance: _avance,
          onVolver: _control.irA,
        ),
        const SizedBox(height: 24),
      ],
      if (material.estaVacio)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'El material de este tema se está preparando.',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      if (material.contenidos.isNotEmpty) ...[
        const _TituloSeccion('Qué aprenderás'),
        for (final contenido in material.contenidos) _FilaContenido(contenido),
        const SizedBox(height: 20),
      ],
      ?widget.practica?.call(quizHabilitado),
      if (organizado.otros.isNotEmpty) ...[
        const SizedBox(height: 20),
        const _TituloSeccion('Más material'),
        for (final recurso in organizado.otros)
          Card(
            child: ListTile(
              leading: Icon(_iconoDe(recurso.tipo)),
              title: Text(recurso.titulo),
              subtitle: Text(_etiquetaDe(recurso.tipo)),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _abrir(recurso),
            ),
          ),
      ],
    ];
  }

  static IconData _iconoDe(TipoRecurso tipo) => switch (tipo) {
    TipoRecurso.video => Icons.play_circle_outline,
    TipoRecurso.pdf => Icons.picture_as_pdf_outlined,
    TipoRecurso.teoria => Icons.menu_book_outlined,
    TipoRecurso.ejemplo => Icons.lightbulb_outline,
    TipoRecurso.ejercicio => Icons.edit_note,
    TipoRecurso.grabacion => Icons.videocam_outlined,
  };

  static String _etiquetaDe(TipoRecurso tipo) => switch (tipo) {
    TipoRecurso.video => 'Video',
    TipoRecurso.pdf => 'PDF',
    TipoRecurso.teoria => 'Teoría',
    TipoRecurso.ejemplo => 'Ejemplo',
    TipoRecurso.ejercicio => 'Ejercicios',
    TipoRecurso.grabacion => 'Grabación',
  };
}

/// Reparte los recursos: la clase (video de YouTube), la separata (va en el
/// botón "+") y el resto.
class _Organizado {
  final MaterialTema material;
  final Recurso? clase;
  final String? videoId;
  final Recurso? separata;
  final List<Recurso> otros;

  const _Organizado({
    required this.material,
    required this.clase,
    required this.videoId,
    required this.separata,
    required this.otros,
  });

  factory _Organizado.de(MaterialTema material) {
    Recurso? clase;
    String? videoId;

    for (final recurso in material.recursos) {
      final id = idYoutube(recurso);
      if (id != null) {
        clase = recurso;
        videoId = id;
        break;
      }
    }

    final separata = material.recursos
        .where((r) => r.tipo == TipoRecurso.pdf || r.tipo == TipoRecurso.teoria)
        .firstOrNull;

    return _Organizado(
      material: material,
      clase: clase,
      videoId: videoId,
      separata: separata,
      otros: [
        for (final r in material.recursos)
          if (r != clase && r != separata) r,
      ],
    );
  }
}

typedef AvanceClase = ({
  double fraccion,
  double duracion,
  double? saltadoDesde,
});

class _AvanceClase extends StatelessWidget {
  final String titulo;
  final ValueNotifier<AvanceClase> avance;
  final void Function(double segundos) onVolver;

  const _AvanceClase({
    required this.titulo,
    required this.avance,
    required this.onVolver,
  });

  static String _reloj(double segundos) {
    final total = segundos.floor();
    final s = (total % 60).toString().padLeft(2, '0');
    return '${total ~/ 60}:$s';
  }

  static String _minutos(double segundos) {
    final minutos = (segundos / 60).round();
    return minutos < 1 ? '1 min' : '$minutos min';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: avance,
      builder: (context, valor, _) {
        final completa = valor.fraccion >= 1;
        final porcentaje = (valor.fraccion * 100).floor();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                titulo,
                if (valor.duracion > 0) _minutos(valor.duracion),
              ].join(' · '),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: valor.fraccion,
                minHeight: 3,
                color: completa ? ColoresApp.texto : ColoresApp.ambar,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              completa
                  ? 'Clase vista por completo · quiz activado'
                  : 'Clase vista: $porcentaje % · termínala para activar el quiz',
              style: const TextStyle(fontSize: 13, color: ColoresApp.apagado),
            ),
            if (valor.saltadoDesde case final desde?)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Te saltaste una parte desde ${_reloj(desde)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: ColoresApp.ambar,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onVolver(desde),
                    child: const Text('Volver ahí'),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Marco del chat de dudas: empieza a la altura del video y termina sobre
/// el teclado, así lo escrito nunca queda tapado.
class _VentanaDudas extends StatelessWidget {
  final Widget child;

  const _VentanaDudas({required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final arriba = media.padding.top + kToolbarHeight + 8;
    final abajo = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom + 8
        : media.padding.bottom + 16;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, arriba, 12, abajo),
      // En la web el video es un iframe que se "come" los clics de lo que se
      // dibuja encima (p. ej. la X). PointerInterceptor lo evita.
      child: PointerInterceptor(
        child: Material(
          color: const Color(0xFF16171C),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: ColoresApp.borde),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FilaContenido extends StatelessWidget {
  final Contenido contenido;

  const _FilaContenido(this.contenido);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${contenido.orden}.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contenido.nombre),
                if (contenido.descripcion != null)
                  Text(
                    contenido.descripcion!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
