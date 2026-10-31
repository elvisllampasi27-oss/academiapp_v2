import 'package:flutter/material.dart';

import '../../domain/errors/excepcion_autenticacion.dart';
import '../../domain/services/completar_perfil_service.dart';
import '../../domain/services/iniciar_sesion_estudiante_service.dart';
import '../../domain/services/iniciar_sesion_google_service.dart';
import '../../domain/services/recuperar_contrasena_service.dart';
import '../../domain/services/registrar_estudiante_service.dart';
import '../../domain/values/validacion_credenciales.dart';
import '../messages/mensajes_autenticacion.dart';
import '../widgets/boton_google.dart';
import '../widgets/estilo_autenticacion.dart';
import 'completar_perfil_page.dart';
import 'recuperar_contrasena_page.dart';
import 'registro_page.dart';

class LoginPage extends StatefulWidget {
  final IniciarSesionEstudianteService iniciarSesionService;
  final RegistrarEstudianteService registrarService;
  final RecuperarContrasenaService recuperarContrasenaService;
  final IniciarSesionGoogleService iniciarSesionGoogleService;
  final CompletarPerfilService completarPerfilService;
  final VoidCallback onSesionIniciada;

  /// Vuelve a la bienvenida (si se llegó desde ahí).
  final VoidCallback? onVolver;

  const LoginPage({
    super.key,
    required this.iniciarSesionService,
    required this.registrarService,
    required this.recuperarContrasenaService,
    required this.iniciarSesionGoogleService,
    required this.completarPerfilService,
    required this.onSesionIniciada,
    this.onVolver,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();

  bool _cargando = false;
  bool _cargandoGoogle = false;
  String? _error;

  @override
  void dispose() {
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final correo = _correoController.text.trim();
    final contrasena = _contrasenaController.text;

    String? errorValidacion;

    if (correo.isEmpty) {
      errorValidacion = 'Ingresa tu correo.';
    } else if (!ValidacionCredenciales.esCorreoValido(correo)) {
      errorValidacion = 'Ingresa un correo válido.';
    } else if (contrasena.isEmpty) {
      errorValidacion = 'Ingresa tu contraseña.';
    }

    if (errorValidacion != null) {
      setState(() => _error = errorValidacion);
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await widget.iniciarSesionService.iniciarSesion(
        correo: correo,
        contrasena: contrasena,
      );

      if (!mounted) return;

      widget.onSesionIniciada();
    } catch (error) {
      if (!mounted) return;

      setState(() => _error = mensajeErrorAutenticacion(error));
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _iniciarConGoogle() async {
    setState(() {
      _cargandoGoogle = true;
      _error = null;
    });

    try {
      final resultado = await widget.iniciarSesionGoogleService.iniciar();

      if (!mounted) return;

      switch (resultado) {
        case InicioGoogleCompleto():
          widget.onSesionIniciada();
        case InicioGoogleRequierePerfil(:final autenticado):
          final completado = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => CompletarPerfilPage(
                autenticado: autenticado,
                service: widget.completarPerfilService,
              ),
            ),
          );

          if (completado == true && mounted) {
            widget.onSesionIniciada();
          }
      }
    } on ExcepcionAutenticacion catch (error) {
      if (!mounted || error.tipo == TipoErrorAutenticacion.cancelado) return;

      setState(() => _error = mensajeErrorAutenticacion(error));
    } catch (error) {
      if (!mounted) return;

      setState(() => _error = mensajeErrorAutenticacion(error));
    } finally {
      if (mounted) {
        setState(() => _cargandoGoogle = false);
      }
    }
  }

  void _irARecuperar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecuperarContrasenaPage(
          service: widget.recuperarContrasenaService,
          correoInicial: _correoController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _irARegistro() async {
    final registrado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistroPage(service: widget.registrarService),
      ),
    );

    if (registrado == true && mounted) {
      widget.onSesionIniciada();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _cargando || _cargandoGoogle;

    return PopScope(
      canPop: widget.onVolver == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onVolver?.call();
      },
      child: FondoAutenticacion(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarraAutenticacion(alVolver: ocupado ? null : widget.onVolver),
            const SizedBox(height: 28),
            TarjetaVidrio(
              capaTrasera: true,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EncabezadoAutenticacion(
                      titulo: 'Iniciar sesión',
                      subtitulo: 'Qué bueno verte de nuevo.',
                    ),
                    CampoVidrio(
                      etiqueta: 'Correo',
                      hint: 'tu@correo.com',
                      controller: _correoController,
                      tipoTeclado: TextInputType.emailAddress,
                      accion: TextInputAction.next,
                      autocompletado: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 16),
                    CampoVidrio(
                      etiqueta: 'Contraseña',
                      hint: '••••••••',
                      controller: _contrasenaController,
                      esContrasena: true,
                      accion: TextInputAction.done,
                      autocompletado: const [AutofillHints.password],
                      alEnviar: (_) => _iniciarSesion(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: EnlaceTexto(
                        texto: '¿Olvidaste tu contraseña?',
                        alPresionar: _irARecuperar,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_error != null) MensajeErrorVidrio(mensaje: _error!),
                    BotonVidrio(
                      texto: 'Entrar',
                      principal: true,
                      cargando: _cargando,
                      alPresionar: _cargandoGoogle ? null : _iniciarSesion,
                    ),
                    const SizedBox(height: 12),
                    BotonGoogle(
                      cargando: _cargandoGoogle,
                      alPresionar: _cargando ? null : _iniciarConGoogle,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            PreguntaConEnlace(
              pregunta: '¿No tienes cuenta?',
              enlace: 'Crear cuenta',
              alPresionar: ocupado ? null : _irARegistro,
            ),
          ],
        ),
      ),
    );
  }
}
