import 'package:flutter/material.dart';

import '../../../../app/estudiante_shell.dart';
import '../../../../app/inicio/inicio_page.dart';

import '../../../academic/domain/entities/contexto_dia_estudiante.dart';
import '../../../academic/domain/entities/curriculo.dart';
import '../../../academic/domain/entities/curso.dart';
import '../../../academic/domain/entities/tema.dart';
import '../../../academic/domain/entities/version_academica.dart';
import '../../../academic/domain/services/construir_dia_estudiante_service.dart';
import '../../../academic/domain/services/obtener_material_tema_service.dart';
import '../../../academic/infrastructure/repositories/repositorio_contenido_firestore.dart';
import '../../../academic/infrastructure/repositories/repositorio_curriculo_firestore.dart';
import '../../../academic/infrastructure/repositories/repositorio_plan_academico_firestore.dart';
import '../../../academic/infrastructure/repositories/repositorio_progreso_clase_firestore.dart';
import '../../../academic/infrastructure/repositories/repositorio_recurso_firestore.dart';
import '../../../academic/infrastructure/repositories/repositorio_version_academica_firestore.dart';
import '../../../academic/presentation/pages/curso_detalle_page.dart';
import '../../../academic/presentation/pages/cursos_page.dart';
import '../../../academic/presentation/pages/tema_page.dart';
import '../../../adaptive_engine/domain/entities/item_mi_ruta.dart';
import '../../../adaptive_engine/domain/services/construir_mi_ruta_service.dart';
import '../../../adaptive_engine/presentation/pages/mi_ruta_page.dart';
import '../../../assessment/domain/services/practica_tema_service.dart';
import '../../../assessment/infrastructure/repositories/repositorio_evaluacion_firestore.dart';
import '../../../assessment/infrastructure/services/servicio_correccion_cloud_functions.dart';
import '../../../assessment/presentation/widgets/seccion_practica_tema.dart';
import '../../../enrollment/domain/entities/matricula.dart';
import '../../../exams/infrastructure/repositorio_examenes_firestore.dart';
import '../../../exams/infrastructure/servicio_examenes_cloud_functions.dart';
import '../../../exams/presentation/pages/examenes_page.dart';
import '../../../enrollment/infrastructure/repositories/repositorio_matricula_firestore.dart';
import '../../../seminars/infrastructure/repositorio_seminarios_firestore.dart';
import '../../../seminars/presentation/seminarios_page.dart';
import '../../../student_model/infrastructure/repositories/repositorio_evidencia_firestore.dart';
import '../../../tutor_rag/infrastructure/services/servicio_tutor_cloud_functions.dart';
import '../../../tutor_rag/presentation/conversacion_tutor.dart';
import '../../../tutor_rag/presentation/widgets/panel_tutor.dart';
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
import 'bienvenida_page.dart';
import 'login_page.dart';
import 'perfil_page.dart';
import 'registro_page.dart';

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

  /// Sin sesión se muestra primero la bienvenida; luego el login.
  bool _mostrarLogin = false;

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

  RegistrarEstudianteService get _registrarService =>
      RegistrarEstudianteService(
        servicioAutenticacion: widget.servicioAutenticacion,
        repositorioUsuario: widget.repositorioUsuario,
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
    await widget.servicioAutenticacion.cerrarSesion();

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
          return _HomeConMatricula(
            key: ValueKey(usuario.uid),
            usuario: usuario,
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
            servicioAutenticacion: widget.servicioAutenticacion,
            repositorioUsuario: widget.repositorioUsuario,
          ),
          registrarService: _registrarService,
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
  late Future<_ContextoAcademico?> _contextoAcademico;
  final ValueNotifier<int> _pestana = ValueNotifier(0);
  int _recargas = 0;

  @override
  void initState() {
    super.initState();
    _contextoAcademico = _cargarContextoAcademico();
  }

  @override
  void dispose() {
    _pestana.dispose();
    super.dispose();
  }

  /// Vuelve a leer el día y la ruta (p. ej. al volver de practicar un tema).
  void _recargar() {
    setState(() {
      _recargas++;
      _contextoAcademico = _cargarContextoAcademico();
    });
  }

  late final _repositorioProgreso = RepositorioProgresoClaseFirestore();
  late final _servicioTutor = ServicioTutorCloudFunctions();
  late final _repositorioExamenes = RepositorioExamenesFirestore();
  late final _servicioExamenes = ServicioExamenesCloudFunctions();

  ConstruirMiRutaService get _servicioRuta =>
      ConstruirMiRutaService(repositorio: RepositorioEvidenciaFirestore());

  Future<List<ItemMiRuta>> _cargarRuta(String matriculaId) async {
    try {
      return await _servicioRuta.construir(
        usuarioId: widget.usuario.uid,
        matriculaId: matriculaId,
      );
    } catch (_) {
      // La ruta es un complemento: si falla, el inicio igual se muestra.
      return const [];
    }
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

    // Temario y publicaciones de la versión: 2 lecturas, compartidas por
    // el inicio y la pestaña Cursos.
    final curriculo = RepositorioCurriculoFirestore(
      versionId: matricula.versionId,
    );

    final construirDia = ConstruirDiaEstudianteService(
      repositorioPlan: RepositorioPlanAcademicoFirestore(),
      repositorioCurso: curriculo.cursos,
      repositorioTema: curriculo.temas,
      repositorioPublicacion: curriculo,
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
      ruta: await _cargarRuta(matricula.id),
      curriculo: await curriculo.obtener(),
      publicados: await curriculo.temasPublicados(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ContextoAcademico?>(
      future: _contextoAcademico,
      builder: (context, snapshot) {
        // Al recargar se mantiene lo anterior en pantalla (sin parpadeo).
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
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

        return EstudianteShell(
          indice: _pestana,
          pestanas: [
            PestanaApp(
              etiqueta: 'Inicio',
              icono: Icons.home_outlined,
              contenido: InicioPage(
                nombre: widget.usuario.nombre,
                hoy: DateTime.now(),
                dia: contexto.diaEstudiante,
                ruta: contexto.ruta,
                onAbrirTema: (tema, curso) => _abrirTema(contexto, tema, curso),
                onVerRuta: () => _pestana.value = 3,
                onAbrirPerfil: () => _pestana.value = 4,
              ),
            ),
            PestanaApp(
              etiqueta: 'Cursos',
              icono: Icons.grid_view_rounded,
              contenido: CursosPage(
                curriculo: contexto.curriculo,
                publicados: contexto.publicados,
                onAbrirCurso: (curso) => _abrirCurso(contexto, curso),
              ),
            ),
            PestanaApp(
              etiqueta: 'Exámenes',
              icono: Icons.assignment_outlined,
              contenido: ExamenesPage(
                repositorio: _repositorioExamenes,
                servicio: _servicioExamenes,
                hoy: DateTime.now(),
              ),
            ),
            PestanaApp(
              etiqueta: 'Progreso',
              icono: Icons.insights_outlined,
              contenido: _miRuta(contexto, titulo: 'Progreso'),
            ),
            PestanaApp(
              etiqueta: 'Perfil',
              icono: Icons.person_outline,
              contenido: PerfilPage(
                usuario: widget.usuario,
                onCerrarSesion: widget.onCerrarSesion,
                onAbrirSeminarios: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SeminariosPage(
                      repositorio: RepositorioSeminariosFirestore(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _abrirCurso(_ContextoAcademico contexto, Curso curso) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CursoDetallePage(
          curso: curso,
          nombreArea: contexto.curriculo.area(curso.areaId)?.nombre,
          temas: contexto.curriculo.temasDe(curso.id),
          publicados: contexto.publicados,
          practicados: {for (final item in contexto.ruta) ?item.temaId},
          hoy: {
            for (final actividad in contexto.diaEstudiante.actividades)
              actividad.temaId,
          },
          onAbrirTema: (tema) => _abrirTema(contexto, tema, curso),
        ),
      ),
    );
  }

  Future<void> _abrirTema(
    _ContextoAcademico contexto,
    Tema tema,
    Curso? curso,
  ) async {
    final versionId = contexto.matricula.versionId;
    final conversacion = ConversacionTutor(
      servicio: _servicioTutor,
      versionId: versionId,
      temaId: tema.id,
    );
    final practica = PracticaTemaService(
      repositorio: RepositorioEvaluacionFirestore(),
      correccion: ServicioCorreccionCloudFunctions(),
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemaPage(
          tema: tema,
          curso: curso,
          versionId: versionId,
          usuarioId: widget.usuario.uid,
          service: ObtenerMaterialTemaService(
            repositorioContenido: RepositorioContenidoFirestore(),
            repositorioRecurso: RepositorioRecursoFirestore(),
          ),
          repositorioProgreso: _repositorioProgreso,
          practica: (habilitada) => SeccionPracticaTema(
            service: practica,
            temaId: tema.id,
            versionId: versionId,
            tituloTema: tema.titulo,
            habilitada: habilitada,
          ),
          dudas: (cerrar) => PanelTutor(
            conversacion: conversacion,
            tituloTema: tema.titulo,
            onCerrar: cerrar,
          ),
        ),
      ),
    );

    conversacion.dispose();

    // Al volver puede haber practicado: se actualizan el día y la ruta.
    if (mounted) _recargar();
  }

  Widget _miRuta(_ContextoAcademico contexto, {String titulo = 'Mi Ruta'}) {
    final temas = {for (final t in contexto.diaEstudiante.temas) t.id: t};
    final cursos = {for (final c in contexto.diaEstudiante.cursos) c.id: c};

    return MiRutaPage(
      key: ValueKey('ruta-$_recargas'),
      titulo: titulo,
      service: _servicioRuta,
      usuarioId: widget.usuario.uid,
      matriculaId: contexto.matricula.id,
      describirTema: (temaId) {
        final tema = temas[temaId];
        if (tema == null) return null;
        return (titulo: tema.titulo, curso: cursos[tema.cursoId]?.nombre);
      },
      onAbrirTema: (temaId) {
        final tema = temas[temaId];
        if (tema != null) _abrirTema(contexto, tema, cursos[tema.cursoId]);
      },
    );
  }
}

class _ContextoAcademico {
  final Matricula matricula;
  final VersionAcademica versionAcademica;
  final ContextoDiaEstudiante diaEstudiante;
  final List<ItemMiRuta> ruta;
  final Curriculo curriculo;
  final Set<String> publicados;

  const _ContextoAcademico({
    required this.matricula,
    required this.versionAcademica,
    required this.diaEstudiante,
    required this.ruta,
    required this.curriculo,
    required this.publicados,
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
