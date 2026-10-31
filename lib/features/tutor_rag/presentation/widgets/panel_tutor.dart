import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/texto_con_latex.dart';
import '../../domain/entities/mensaje_tutor.dart';
import '../conversacion_tutor.dart';

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

class _PanelTutorState extends State<PanelTutor> {
  final _texto = TextEditingController();

  void _enviar() {
    final texto = _texto.text;
    if (texto.trim().isEmpty || widget.conversacion.pensando) return;

    _texto.clear();
    widget.conversacion.preguntar(texto);
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
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
                        if (conversacion.pensando) const _Pensando(),
                        for (final mensaje in mensajes.reversed)
                          _Burbuja(mensaje),
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Escribe lo que no entendiste de «$tituloTema»: un paso, '
          'un concepto o un ejercicio.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ColoresApp.apagado, height: 1.5),
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final MensajeTutor mensaje;

  const _Burbuja(this.mensaje);

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
            : TextoConLatex(mensaje.texto),
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
