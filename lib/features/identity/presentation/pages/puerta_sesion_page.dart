import 'package:flutter/material.dart';

import '../../../academic/domain/entities/version_academica.dart';
import '../../../academic/infrastructure/repositories/repositorio_version_academica_firestore.dart';
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

    _estadoInicial = _resolverEstado();
  }

  Future<EstadoSesionEstudiante> _resolverEstado() {
    final recuperarSesion = RecuperarSesionEstudianteService(
      servicioAutenticacion: widget.servicioAutenticacion,
      repositorioUsuario: widget.repositorioUsuario,
    );

    final resolver = ResolverEstadoInicialSesionService(
      recuperarSesion: recuperarSesion,
    );

    return resolver.resolver();
  }

  void _alIniciarSesion() {
    setState(() {
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
          return _HomeConMatricula(usuarioId: usuario.uid);
        }

        return LoginPage(
          iniciarSesionService: IniciarSesionEstudianteService(
            servicioAutenticacion: widget.servicioAutenticacion,
            repositorioUsuario: widget.repositorioUsuario,
          ),
          onSesionIniciada: _alIniciarSesion,
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
  late final Future<_ContextoAcademico?> _contextoAcademico;

  @override
  void initState() {
    super.initState();

    _contextoAcademico = _cargarContextoAcademico();
  }

  Future<_ContextoAcademico?> _cargarContextoAcademico() async {
    final repositorioMatricula = RepositorioMatriculaFirestore();

    final matricula = await repositorioMatricula.buscarActivaPorUsuarioId(
      widget.usuarioId,
    );

    if (matricula == null) {
      return null;
    }

    final repositorioVersion = RepositorioVersionAcademicaFirestore();

    final version = await repositorioVersion.buscarPorId(matricula.versionId);

    if (version == null) {
      throw StateError(
        'La versión académica ${matricula.versionId} no existe.',
      );
    }

    return _ContextoAcademico(matricula: matricula, versionAcademica: version);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ContextoAcademico?>(
      future: _contextoAcademico,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'ERROR:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final contexto = snapshot.data;

        if (contexto == null) {
          return const Scaffold(
            body: Center(child: Text('No tienes una matrícula activa.')),
          );
        }

        return HomePage(
          matricula: contexto.matricula,
          versionAcademica: contexto.versionAcademica,
        );
      },
    );
  }
}

class _ContextoAcademico {
  final Matricula matricula;
  final VersionAcademica versionAcademica;

  const _ContextoAcademico({
    required this.matricula,
    required this.versionAcademica,
  });
}
