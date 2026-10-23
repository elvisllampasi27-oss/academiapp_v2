import 'package:flutter/material.dart';

import '../../../academic/presentation/pages/home_page.dart';
import '../../../enrollment/domain/entities/matricula.dart';
import '../../../enrollment/infrastructure/repositories/repositorio_matricula_firestore.dart';
import '../../domain/entities/estado_sesion_estudiante.dart';
import '../../domain/repositories/repositorio_usuario.dart';
import '../../domain/repositories/servicio_autenticacion.dart';
import '../../domain/services/iniciar_sesion_estudiante_service.dart';
import '../../domain/services/recuperar_sesion_estudiante_service.dart';
import '../../domain/services/resolver_estado_inicial_sesion_service.dart';
import 'login_page.dart';

class PuertaSesionPage extends StatefulWidget {
  final ServicioAutenticacion servicioAutenticacion;
  final RepositorioUsuario repositorioUsuario;

  const PuertaSesionPage({
    super.key,
    required this.servicioAutenticacion,
    required this.repositorioUsuario,
  });

  @override
  State<PuertaSesionPage> createState() => _PuertaSesionPageState();
}

class _PuertaSesionPageState extends State<PuertaSesionPage> {
  late Future<EstadoSesionEstudiante> _estadoInicial;

  @override
  void initState() {
    super.initState();
    _resolverEstado();
  }

  void _resolverEstado() {
    final recuperarSesion = RecuperarSesionEstudianteService(
      servicioAutenticacion: widget.servicioAutenticacion,
      repositorioUsuario: widget.repositorioUsuario,
    );

    final resolver = ResolverEstadoInicialSesionService(
      recuperarSesion: recuperarSesion,
    );

    _estadoInicial = resolver.resolver();
  }

  void _sesionIniciada() {
    setState(() {
      _resolverEstado();
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

        if (estado?.tipo == TipoEstadoSesionEstudiante.autenticado &&
            estado?.usuario != null) {
          return _HomeConMatricula(usuarioId: estado!.usuario!.uid);
        }

        final iniciarSesionService = IniciarSesionEstudianteService(
          servicioAutenticacion: widget.servicioAutenticacion,
          repositorioUsuario: widget.repositorioUsuario,
        );

        return LoginPage(
          iniciarSesionService: iniciarSesionService,
          onSesionIniciada: _sesionIniciada,
        );
      },
    );
  }
}

class _HomeConMatricula extends StatefulWidget {
  final String usuarioId;

  const _HomeConMatricula({required this.usuarioId});

  @override
  State<_HomeConMatricula> createState() => _HomeConMatriculaState();
}

class _HomeConMatriculaState extends State<_HomeConMatricula> {
  late final Future<Matricula?> _matricula;

  @override
  void initState() {
    super.initState();

    final repositorio = RepositorioMatriculaFirestore();

    _matricula = repositorio.buscarActivaPorUsuarioId(widget.usuarioId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Matricula?>(
      future: _matricula,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('No se pudo consultar la matrícula.')),
          );
        }

        final matricula = snapshot.data;

        if (matricula == null) {
          return const Scaffold(
            body: Center(child: Text('No tienes una matrícula activa.')),
          );
        }

        return HomePage(matricula: matricula);
      },
    );
  }
}
