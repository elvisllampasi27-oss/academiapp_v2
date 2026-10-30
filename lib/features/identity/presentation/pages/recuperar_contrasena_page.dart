import 'package:flutter/material.dart';

import '../../domain/services/recuperar_contrasena_service.dart';
import '../messages/mensajes_autenticacion.dart';
import '../widgets/estilo_autenticacion.dart';

class RecuperarContrasenaPage extends StatefulWidget {
  final RecuperarContrasenaService service;
  final String correoInicial;

  const RecuperarContrasenaPage({
    super.key,
    required this.service,
    this.correoInicial = '',
  });

  @override
  State<RecuperarContrasenaPage> createState() =>
      _RecuperarContrasenaPageState();
}

class _RecuperarContrasenaPageState extends State<RecuperarContrasenaPage> {
  late final TextEditingController _correoController = TextEditingController(
    text: widget.correoInicial,
  );

  bool _cargando = false;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await widget.service.enviar(_correoController.text);

      if (!mounted) return;

      setState(() => _enviado = true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _error = mensajeErrorAutenticacion(error));
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FondoAutenticacion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Volver',
              color: Colors.white,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const EncabezadoAutenticacion(
            titulo: 'Recupera tu contraseña',
            subtitulo: 'Te enviaremos un enlace para crear una nueva.',
          ),
          TarjetaVidrio(child: _enviado ? _confirmacion() : _formulario()),
        ],
      ),
    );
  }

  Widget _formulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampoVidrio(
          hint: 'Correo electrónico',
          controller: _correoController,
          tipoTeclado: TextInputType.emailAddress,
          accion: TextInputAction.done,
          autocompletado: const [AutofillHints.email],
          alEnviar: (_) => _enviar(),
        ),
        const SizedBox(height: 16),
        if (_error != null) MensajeErrorVidrio(mensaje: _error!),
        BotonVidrio(
          texto: 'Enviar enlace',
          cargando: _cargando,
          alPresionar: _enviar,
        ),
      ],
    );
  }

  Widget _confirmacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Revisa tu correo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Si ${_correoController.text.trim()} está registrado en AcademiApp, '
          'recibirás un enlace para restablecer tu contraseña. '
          'Revisa también la carpeta de spam.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 20),
        BotonVidrio(
          texto: 'Volver al inicio de sesión',
          alPresionar: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
