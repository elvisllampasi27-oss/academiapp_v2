import 'package:flutter/material.dart';

import '../../../academic/domain/entities/contexto_dia_estudiante.dart';
import '../../../academic/domain/entities/version_academica.dart';
import '../../../academic/domain/services/construir_dia_estudiante_service.dart';
import '../../../academic/infrastructure/repositories/repositorio_curso_firestore.dart';
import '../../../academic/infrastructure/repositories/repositorio_plan_academico_firestore.dart';
import '../../../academic/infrastructure/repositories/repositorio_publicacion_tema_firestore.dart';
import '../../../academic/infrastructure/repositories/repositorio_tema_firestore.dart';
import '../../../academic/infrastructure/repositories/repositorio_version_academica_firestore.dart';
import '../../../academic/presentation/pages/home_page.dart';
import '../../../enrollment/domain/entities/matricula.dart';
import '../../../enrollment/infrastructure/repositories/repositorio_matricula_firestore.dart';
import '../../domain/entities/estado_sesion_estudiante.dart';
import '../../domain/entities/usuario_academiapp.dart';
import '../../domain/repositories/repositorio_usuario.dart';
import '../../domain/repositories/servicio_autenticacion.dart';
import '../../domain/repositories/servicio_autenticacion_google.dart';
import '../../domain/repositories/servicio_recuperacion_contrasena.dart';
import '../../domain/services/completar_perfil_service.dart';
import '../../domain/services/iniciar_sesion_estudiante_service.dart';
import '../../domain/services/iniciar_sesion_google_service.dart';
import '../../domain/services/recuperar_contrasena_service.dart';
import '../../domain/services/recuperar_sesion_estudiante_service.dart';
import '../../domain/services/registrar_estudiante_service.dart';
import '../../domain/services/resolver_estado_inicial_sesion_service.dart';
import 'login_page.dart';

class PuertaSesionPage extends StatefulWidget {
  final ServicioAutenticacion servicioAutenticacion;
  final ServicioRecuperacionContrasena servicioRecuperacion;
  final ServicioAutenticacionGoogle servicioGoogle;
  final RepositorioUsuario repositorioUsuario;

  const PuertaSesionPage({
    super.key,
    required this.servicioAutenticacion,
    required this.servicioRecuperacion,
    required this.servicioGoogle,
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

  Future<void> _cerrarSesion() async {
    await widget.servicioAutenticacion.cerrarSesion();

    if (!mounted) return;

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
          return _HomeConMatricula(
            key: ValueKey(usuario.uid),
            usuario: usuario,
            onCerrarSesion: _cerrarSesion,
          );
        }

        return LoginPage(
          iniciarSesionService: IniciarSesionEstudianteService(
            servicioAutenticacion: widget.servicioAutenticacion,
            repositorioUsuario: widget.repositorioUsuario,
          ),
          registrarService: RegistrarEstudianteService(
            servicioAutenticacion: widget.servicioAutenticacion,
            repositorioUsuario: widget.repositorioUsuario,
          ),
          recuperarContrasenaService: RecuperarContrasenaService(
            servicio: widget.servicioRecuperacion,
          ),
          iniciarSesionGoogleService: IniciarSesionGoogleService(
            servicioGoogle: widget.servicioGoogle,
            servicioAutenticacion: widget.servicioAutenticacion,
            repositorioUsuario: widget.repositorioUsuario,
          ),
          completarPerfilService: CompletarPerfilService(
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
  final UsuarioAcademiApp usuario;
  final Future<void> Function() onCerrarSesion;

  const _HomeConMatricula({
    super.key,
    required this.usuario,
    required this.onCerrarSesion,
  });

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
      widget.usuario.uid,
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

    final construirDia = ConstruirDiaEstudianteService(
      repositorioPlan: RepositorioPlanAcademicoFirestore(),
      repositorioCurso: RepositorioCursoFirestore(),
      repositorioTema: RepositorioTemaFirestore(),
      repositorioPublicacion: RepositorioPublicacionTemaFirestore(),
    );

    final diaEstudiante = await construirDia.construir(
      versionId: matricula.versionId,
      fechaInicioAcademico: matricula.fechaInicioAcademico,
      fechaActual: DateTime.now(),
    );

    if (diaEstudiante == null) {
      throw StateError(
        'No existe un plan académico activo para ${matricula.versionId}.',
      );
    }

    return _ContextoAcademico(
      matricula: matricula,
      versionAcademica: version,
      diaEstudiante: diaEstudiante,
    );
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
          // Deuda: antes de producción, registrar el error y mostrar un
          // mensaje genérico en lugar del detalle técnico.
          return _PantallaAviso(
            titulo: 'No se pudo cargar la información académica',
            mensaje: snapshot.error.toString(),
            onCerrarSesion: widget.onCerrarSesion,
          );
        }

        final contexto = snapshot.data;

        if (contexto == null) {
          return _PantallaAviso(
            titulo: 'Hola, ${widget.usuario.nombre}',
            mensaje:
                'Tu cuenta está lista, pero todavía no tienes una matrícula '
                'activa. Cuando se active, aquí verás tus actividades del día.',
            onCerrarSesion: widget.onCerrarSesion,
          );
        }

        return HomePage(
          matricula: contexto.matricula,
          versionAcademica: contexto.versionAcademica,
          diaEstudiante: contexto.diaEstudiante,
          onCerrarSesion: widget.onCerrarSesion,
        );
      },
    );
  }
}

class _ContextoAcademico {
  final Matricula matricula;
  final VersionAcademica versionAcademica;
  final ContextoDiaEstudiante diaEstudiante;

  const _ContextoAcademico({
    required this.matricula,
    required this.versionAcademica,
    required this.diaEstudiante,
  });
}

class _PantallaAviso extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final Future<void> Function() onCerrarSesion;

  const _PantallaAviso({
    required this.titulo,
    required this.mensaje,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AcademiApp')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(mensaje, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: onCerrarSesion,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
