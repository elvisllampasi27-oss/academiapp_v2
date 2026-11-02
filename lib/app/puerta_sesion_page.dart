import 'package:flutter/material.dart';

import '../features/identity/domain/entities/estado_sesion_estudiante.dart';
import '../features/identity/domain/services/completar_perfil_service.dart';
import '../features/identity/domain/services/iniciar_sesion_estudiante_service.dart';
import '../features/identity/domain/services/iniciar_sesion_google_service.dart';
import '../features/identity/domain/services/recuperar_contrasena_service.dart';
import '../features/identity/domain/services/recuperar_sesion_estudiante_service.dart';
import '../features/identity/domain/services/registrar_estudiante_service.dart';
import '../features/identity/domain/services/resolver_estado_inicial_sesion_service.dart';
import '../features/identity/presentation/pages/bienvenida_page.dart';
import '../features/identity/presentation/pages/login_page.dart';
import '../features/identity/presentation/pages/registro_page.dart';
import 'dependencias.dart';
import 'home_estudiante.dart';

/// Decide qué ve el estudiante: bienvenida, login o su inicio.
class PuertaSesionPage extends StatefulWidget {
  final Dependencias dependencias;

  const PuertaSesionPage({super.key, required this.dependencias});

  @override
  State<PuertaSesionPage> createState() => _PuertaSesionPageState();
}

class _PuertaSesionPageState extends State<PuertaSesionPage> {
  late Future<EstadoSesionEstudiante> _estadoInicial;

  /// Sin sesión se muestra primero la bienvenida; luego el login.
  bool _mostrarLogin = false;

  Dependencias get _d => widget.dependencias;

  @override
  void initState() {
    super.initState();
    _estadoInicial = _resolverEstado();
  }

  Future<EstadoSesionEstudiante> _resolverEstado() {
    final recuperarSesion = RecuperarSesionEstudianteService(
      servicioAutenticacion: _d.autenticacion,
      repositorioUsuario: _d.usuarios,
    );

    final resolver = ResolverEstadoInicialSesionService(
      recuperarSesion: recuperarSesion,
    );

    return resolver.resolver();
  }

  RegistrarEstudianteService get _registrarService =>
      RegistrarEstudianteService(
        servicioAutenticacion: _d.autenticacion,
        repositorioUsuario: _d.usuarios,
      );

  Future<void> _crearCuenta() async {
    final registrado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistroPage(service: _registrarService),
      ),
    );

    if (registrado == true && mounted) _alIniciarSesion();
  }

  void _alIniciarSesion() {
    setState(() {
      _estadoInicial = _resolverEstado();
    });
  }

  Future<void> _cerrarSesion() async {
    await _d.autenticacion.cerrarSesion();

    if (!mounted) return;

    setState(() {
      _mostrarLogin = true;
      _estadoInicial = _resolverEstado();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EstadoSesionEstudiante>(
      future: _estadoInicial,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final estado = snapshot.data;
        final usuario = estado?.usuario;

        if (estado?.tipo == TipoEstadoSesionEstudiante.autenticado &&
            usuario != null) {
          return HomeEstudiante(
            key: ValueKey(usuario.uid),
            usuario: usuario,
            dependencias: _d,
            onCerrarSesion: _cerrarSesion,
          );
        }

        if (!_mostrarLogin) {
          return BienvenidaPage(
            onEmpezar: () => setState(() => _mostrarLogin = true),
            onCrearCuenta: _crearCuenta,
          );
        }

        return LoginPage(
          onVolver: () => setState(() => _mostrarLogin = false),
          iniciarSesionService: IniciarSesionEstudianteService(
            servicioAutenticacion: _d.autenticacion,
            repositorioUsuario: _d.usuarios,
          ),
          registrarService: _registrarService,
          recuperarContrasenaService: RecuperarContrasenaService(
            servicio: _d.recuperacion,
          ),
          iniciarSesionGoogleService: IniciarSesionGoogleService(
            servicioGoogle: _d.google,
            servicioAutenticacion: _d.autenticacion,
            repositorioUsuario: _d.usuarios,
          ),
          completarPerfilService: CompletarPerfilService(
            servicioAutenticacion: _d.autenticacion,
            repositorioUsuario: _d.usuarios,
          ),
          onSesionIniciada: _alIniciarSesion,
        );
      },
    );
  }
}
