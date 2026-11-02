import 'package:flutter/material.dart';

import '../features/academic/domain/entities/curso.dart';
import '../features/academic/domain/entities/tema.dart';
import '../features/academic/domain/services/obtener_material_tema_service.dart';
import '../features/academic/presentation/pages/curso_detalle_page.dart';
import '../features/academic/presentation/pages/cursos_page.dart';
import '../features/academic/presentation/pages/tema_page.dart';
import '../features/adaptive_engine/domain/services/construir_mi_ruta_service.dart';
import '../features/adaptive_engine/presentation/pages/mi_ruta_page.dart';
import '../features/assessment/domain/services/practica_tema_service.dart';
import '../features/assessment/presentation/widgets/seccion_practica_tema.dart';
import '../features/exams/presentation/pages/examenes_page.dart';
import '../features/identity/domain/entities/usuario_academiapp.dart';
import '../features/identity/presentation/pages/perfil_page.dart';
import '../features/seminars/presentation/seminarios_page.dart';
import '../features/tutor/presentation/conversacion_tutor.dart';
import '../features/tutor/presentation/widgets/panel_tutor.dart';
import 'dependencias.dart';
import 'estudiante_shell.dart';
import 'inicio/contexto_academico.dart';
import 'inicio/inicio_page.dart';

/// Inicio del estudiante con sesión: carga su contexto académico y arma
/// las pestañas y la navegación entre módulos.
class HomeEstudiante extends StatefulWidget {
  final UsuarioAcademiApp usuario;
  final Dependencias dependencias;
  final Future<void> Function() onCerrarSesion;

  const HomeEstudiante({
    super.key,
    required this.usuario,
    required this.dependencias,
    required this.onCerrarSesion,
  });

  @override
  State<HomeEstudiante> createState() => _HomeEstudianteState();
}

class _HomeEstudianteState extends State<HomeEstudiante> {
  late Future<ContextoAcademico?> _contextoAcademico;
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

  Dependencias get _d => widget.dependencias;

  ConstruirMiRutaService get _servicioRuta =>
      ConstruirMiRutaService(repositorio: _d.evidencias);

  Future<ContextoAcademico?> _cargarContextoAcademico() {
    return CargarContextoAcademicoService(
      matriculas: _d.matriculas,
      versiones: _d.versiones,
      planes: _d.planes,
      curriculoDe: _d.curriculoDe,
      ruta: _servicioRuta,
    ).cargar(usuarioId: widget.usuario.uid, ahora: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContextoAcademico?>(
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
                repositorio: _d.examenes,
                servicio: _d.servicioExamenes,
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
                    builder: (_) => SeminariosPage(repositorio: _d.seminarios),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _abrirCurso(ContextoAcademico contexto, Curso curso) {
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
    ContextoAcademico contexto,
    Tema tema,
    Curso? curso,
  ) async {
    final versionId = contexto.matricula.versionId;
    final conversacion = ConversacionTutor(
      servicio: _d.tutor,
      versionId: versionId,
      temaId: tema.id,
    );
    final practica = PracticaTemaService(
      repositorio: _d.evaluaciones,
      correccion: _d.correccion,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemaPage(
          tema: tema,
          curso: curso,
          versionId: versionId,
          usuarioId: widget.usuario.uid,
          service: ObtenerMaterialTemaService(
            repositorioContenido: _d.contenidos,
            repositorioRecurso: _d.recursos,
          ),
          repositorioProgreso: _d.progresoClases,
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

  Widget _miRuta(ContextoAcademico contexto, {String titulo = 'Mi Ruta'}) {
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
