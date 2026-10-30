import 'package:flutter/material.dart';

import '../../domain/entities/usuario_autenticado.dart';
import '../../domain/services/completar_perfil_service.dart';
import '../../domain/values/carreras_unsch.dart';
import '../messages/mensajes_autenticacion.dart';
import '../widgets/estilo_autenticacion.dart';

/// Primer ingreso con Google: falta crear el perfil de AcademiApp.
/// Hace `pop(true)` al guardar y `pop(false)` si el estudiante cancela.
class CompletarPerfilPage extends StatefulWidget {
  final UsuarioAutenticado autenticado;
  final CompletarPerfilService service;

  const CompletarPerfilPage({
    super.key,
    required this.autenticado,
    required this.service,
  });

  @override
  State<CompletarPerfilPage> createState() => _CompletarPerfilPageState();
}

class _CompletarPerfilPageState extends State<CompletarPerfilPage> {
  late final TextEditingController _nombreController = TextEditingController(
    text: widget.autenticado.nombre ?? '',
  );

  String? _carrera;
  String? _error;
  bool _cargando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombreController.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa tu nombre completo.');
      return;
    }

    if (_carrera == null) {
      setState(() => _error = 'Selecciona la carrera a la que postulas.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await widget.service.completar(
        autenticado: widget.autenticado,
        nombre: _nombreController.text,
        carreraPostulada: _carrera,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _error = mensajeErrorAutenticacion(error));
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _cancelar() async {
    await widget.service.cancelar();

    if (!mounted) return;

    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_cargando) _cancelar();
      },
      child: FondoAutenticacion(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EncabezadoAutenticacion(
              titulo: 'Completa tu perfil',
              subtitulo:
                  'Solo falta un paso. Entraste como '
                  '${widget.autenticado.correo ?? 'usuario de Google'}.',
            ),
            TarjetaVidrio(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CampoVidrio(
                    hint: 'Nombre completo',
                    controller: _nombreController,
                    accion: TextInputAction.done,
                    autocompletado: const [AutofillHints.name],
                  ),
                  const SizedBox(height: 16),
                  SelectorVidrio(
                    hint: 'Carrera a la que postulas',
                    valor: _carrera,
                    opciones: carrerasUnsch,
                    alCambiar: (valor) => setState(() => _carrera = valor),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) MensajeErrorVidrio(mensaje: _error!),
                  BotonVidrio(
                    texto: 'Continuar',
                    cargando: _cargando,
                    alPresionar: _guardar,
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: EnlaceTexto(
                      texto: 'Cancelar y salir',
                      alPresionar: () {
                        if (!_cargando) _cancelar();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
