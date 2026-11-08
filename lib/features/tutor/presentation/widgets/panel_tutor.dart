import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/texto_con_latex.dart';
import '../../domain/entities/mensaje_tutor.dart';
import '../conversacion_tutor.dart';
import '../../../../core/presentation/animaciones.dart';
import '../../../../core/presentation/puma_tutor.dart';
import '../../../../core/presentation/voz_puma.dart';

/// Chat de dudas con el tutor, dentro de la pantalla del tema.
class PanelTutor extends StatefulWidget {
  final ConversacionTutor conversacion;
  final String tituloTema;
  final VoidCallback onCerrar;

  const PanelTutor({
    super.key,
    required this.conversacion,
    required this.tituloTema,
    required this.onCerrar,
  });

  @override
  State<PanelTutor> createState() => _PanelTutorState();
}

class _PanelTutorState extends State<PanelTutor> with WidgetsBindingObserver {
  final _texto = TextEditingController();

  /// Cuánto queda abierta la boca del puma en cada palabra.
  static const _silaba = Duration(milliseconds: 140);

  late final VozPuma _voz = VozPuma.crear(
    alCambiar: (hablando) {
      if (!mounted) return;
      setState(() {
        if (!hablando) {
          _leyendo = null;
          _bocaAbierta = false;
        }
      });
    },
    alPalabra: _moverBoca,
  );
  bool _hayVoz = false;

  /// Respuesta que el puma está leyendo en voz alta (si alguna).
  MensajeTutor? _leyendo;
  bool _bocaAbierta = false;
  Timer? _cerrarBoca;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voz.preparar().then((hay) {
      if (mounted && hay) setState(() => _hayVoz = true);
    });
  }

  /// Al pasar la app a segundo plano, el puma se calla.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed && _leyendo != null) {
      _voz.callar();
    }
  }

  void _moverBoca() {
    if (!mounted || sinAnimaciones(context)) return;
    setState(() => _bocaAbierta = true);
    _cerrarBoca?.cancel();
    _cerrarBoca = Timer(_silaba, () {
      if (mounted) setState(() => _bocaAbierta = false);
    });
  }

  void _escuchar(MensajeTutor mensaje) {
    if (identical(_leyendo, mensaje)) {
      _voz.callar();
      return;
    }
    setState(() => _leyendo = mensaje);
    _voz.hablar(mensaje.texto);
  }

  void _enviar() {
    final texto = _texto.text;
    if (texto.trim().isEmpty || widget.conversacion.pensando) return;

    _texto.clear();
    widget.conversacion.preguntar(texto);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cerrarBoca?.cancel();
    _voz.cerrar(); // al cerrar el chat deja de hablar
    _texto.dispose();
    super.dispose();
  }

  /// La cara del puma según lo que pasa en el chat.
  GestoPuma _gesto(ConversacionTutor conversacion) {
    if (conversacion.pensando) return GestoPuma.pensando;
    if (conversacion.error != null) return GestoPuma.serio;
    return GestoPuma.atento;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.conversacion,
      builder: (context, _) {
        final conversacion = widget.conversacion;
        final mensajes = conversacion.mensajes;
        final restantes = conversacion.restantesHoy;
        final limite = conversacion.limiteDiario;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 6, 10),
              child: Row(
                children: [
                  // El puma es la cara del tutor: piensa mientras espera la
                  // respuesta y mueve la boca al leerla.
                  PumaTutor(
                    gesto: _gesto(conversacion),
                    tamano: 52,
                    hablando: _leyendo != null,
                    bocaAbierta: _bocaAbierta,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tutor',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Responde con el material de ${widget.tituloTema}',
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
                  if (restantes != null && limite != null)
                    Text(
                      '$restantes de $limite hoy',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ColoresApp.apagado,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: widget.onCerrar,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: mensajes.isEmpty && !conversacion.pensando
                  ? _Bienvenida(tituloTema: widget.tituloTema)
                  : ListView(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (conversacion.error case final error?)
                          _AvisoError(error),
                        if (conversacion.pensando)
                          const FilaEntrante(
                            key: ValueKey('pensando'),
                            indice: 0,
                            retraso: Duration.zero,
                            child: _Pensando(),
                          ),
                        for (final mensaje in mensajes.reversed)
                          FilaEntrante(
                            key: ObjectKey(mensaje),
                            indice: 0,
                            retraso: Duration.zero,
                            child: _Burbuja(
                              mensaje,
                              leyendo: identical(_leyendo, mensaje),
                              onEscuchar:
                                  _hayVoz && mensaje.autor == AutorMensaje.tutor
                                  ? () => _escuchar(mensaje)
                                  : null,
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _texto,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 600,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviar(),
                      decoration: InputDecoration(
                        hintText: 'Tu duda',
                        counterText: '',
                        filled: true,
                        fillColor: ColoresApp.panel,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: ColoresApp.borde),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: ColoresApp.borde),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: conversacion.pensando ? null : _enviar,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Bienvenida extends StatelessWidget {
  final String tituloTema;

  const _Bienvenida({required this.tituloTema});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EntradaDifuminada(child: PumaTutor(tamano: 112)),
            const SizedBox(height: 12),
            EntradaDifuminada(
              retraso: const Duration(milliseconds: 150),
              child: Text(
                'Escribe lo que no entendiste de «$tituloTema»: un paso, '
                'un concepto o un ejercicio.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ColoresApp.apagado, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final MensajeTutor mensaje;

  /// Si se da, la respuesta del tutor ofrece "Escuchar".
  final VoidCallback? onEscuchar;
  final bool leyendo;

  const _Burbuja(this.mensaje, {this.onEscuchar, this.leyendo = false});

  @override
  Widget build(BuildContext context) {
    final esEstudiante = mensaje.autor == AutorMensaje.estudiante;

    return Align(
      alignment: esEstudiante ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: esEstudiante ? const Color(0x1FFFFFFF) : ColoresApp.panel,
          borderRadius: BorderRadius.circular(18),
          border: esEstudiante ? null : Border.all(color: ColoresApp.borde),
        ),
        child: esEstudiante
            ? Text(mensaje.texto)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextoConLatex(mensaje.texto),
                  if (onEscuchar case final escuchar?)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: escuchar,
                        style: TextButton.styleFrom(
                          foregroundColor: ColoresApp.apagado,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: Icon(
                          leyendo
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up_outlined,
                          size: 18,
                        ),
                        label: Text(leyendo ? 'Callar' : 'Escuchar'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  final String mensaje;

  const _AvisoError(this.mensaje);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        mensaje,
        style: const TextStyle(color: ColoresApp.naranja, fontSize: 13),
      ),
    );
  }
}

/// "Buscando en tu material…" con tres puntos que saltan.
class _Pensando extends StatefulWidget {
  const _Pensando();

  @override
  State<_Pensando> createState() => _PensandoState();
}

class _PensandoState extends State<_Pensando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  /// Intensidad (0 a 1) del punto [i] en el instante [t].
  static double _pulso(int i, double t) {
    final fase = (t - i * 0.15) % 1.0;
    if (fase > 0.8) return 0;
    final x = fase / 0.8;
    return x < 0.5 ? x * 2 : (1 - x) * 2;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _animacion,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Transform.translate(
                    offset: Offset(0, -3 * _pulso(i, _animacion.value)),
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ColoresApp.texto.withValues(
                          alpha: 0.25 + 0.75 * _pulso(i, _animacion.value),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Buscando en tu material…',
            style: TextStyle(color: ColoresApp.apagado, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
