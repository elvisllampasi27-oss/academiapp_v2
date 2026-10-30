import 'package:flutter/material.dart';

import '../../domain/services/registrar_estudiante_service.dart';
import '../../domain/values/carreras_unsch.dart';
import '../../domain/values/validacion_credenciales.dart';
import '../messages/mensajes_autenticacion.dart';
import '../widgets/estilo_autenticacion.dart';

/// Registro de estudiante. Al terminar con éxito hace `pop(true)`:
/// Firebase deja la sesión iniciada y la puerta de sesión decide a dónde ir.
class RegistroPage extends StatefulWidget {
  final RegistrarEstudianteService service;

  const RegistroPage({super.key, required this.service});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmacionController = TextEditingController();

  String? _carrera;
  String? _error;
  bool _cargando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _confirmacionController.dispose();
    super.dispose();
  }

  String? _validar() {
    final nombre = _nombreController.text.trim();
    final correo = _correoController.text.trim();
    final contrasena = _contrasenaController.text;

    if (nombre.isEmpty) return 'Ingresa tu nombre completo.';
    if (!ValidacionCredenciales.esCorreoValido(correo)) {
      return 'Ingresa un correo válido.';
    }
    if (!ValidacionCredenciales.esContrasenaValida(contrasena)) {
      return 'La contraseña debe tener al menos '
          '${ValidacionCredenciales.longitudMinimaContrasena} caracteres.';
    }
    if (contrasena != _confirmacionController.text) {
      return 'Las contraseñas no coinciden.';
    }
    if (_carrera == null) return 'Selecciona la carrera a la que postulas.';
    return null;
  }

  Future<void> _registrar() async {
    final errorValidacion = _validar();

    if (errorValidacion != null) {
      setState(() => _error = errorValidacion);
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await widget.service.registrar(
        correo: _correoController.text.trim(),
        contrasena: _contrasenaController.text,
        nombre: _nombreController.text.trim(),
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
              onPressed: _cargando ? null : () => Navigator.of(context).pop(),
            ),
          ),
          const EncabezadoAutenticacion(
            titulo: 'Crea tu cuenta',
            subtitulo: 'Tu preparación para la UNSCH empieza aquí.',
          ),
          TarjetaVidrio(
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CampoVidrio(
                    hint: 'Nombre completo',
                    controller: _nombreController,
                    accion: TextInputAction.next,
                    autocompletado: const [AutofillHints.name],
                  ),
                  const SizedBox(height: 16),
                  CampoVidrio(
                    hint: 'Correo electrónico',
                    controller: _correoController,
                    tipoTeclado: TextInputType.emailAddress,
                    accion: TextInputAction.next,
                    autocompletado: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 16),
                  CampoVidrio(
                    hint: 'Contraseña',
                    controller: _contrasenaController,
                    esContrasena: true,
                    accion: TextInputAction.next,
                    autocompletado: const [AutofillHints.newPassword],
                  ),
                  const SizedBox(height: 16),
                  CampoVidrio(
                    hint: 'Confirmar contraseña',
                    controller: _confirmacionController,
                    esContrasena: true,
                    accion: TextInputAction.done,
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
                    texto: 'Crear cuenta',
                    cargando: _cargando,
                    alPresionar: _registrar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
