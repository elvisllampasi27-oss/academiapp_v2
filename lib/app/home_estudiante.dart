import 'dart:async';

import 'package:flutter/material.dart';

import '../features/academic/domain/entities/curriculo.dart';
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
import '../features/avisos/presentation/avisos_inicio.dart';
import '../features/enrollment/presentation/preparar_plan.dart';
import '../features/exams/presentation/pages/examenes_page.dart';
import '../features/exams/presentation/widgets/aviso_examen_semanal.dart';
import '../features/identity/domain/entities/usuario_academiapp.dart';
import '../features/identity/presentation/pages/eliminar_cuenta_page.dart';
import '../features/identity/presentation/pages/perfil_page.dart';
import '../features/premium/domain/repositorio_premium.dart';
import '../features/recordatorios/domain/recordatorios.dart';
import '../features/enrollment/domain/pausa_plan.dart';
import '../features/premium/presentation/premium_page.dart';
import '../features/reportes/domain/reporte.dart';
import '../features/reportes/presentation/reportar.dart';
import '../features/seminars/presentation/seminarios_page.dart';
import '../features/narrations/presentation/seccion_narraciones.dart';
import '../features/teachers/domain/clase_docente.dart';
import '../features/teachers/presentation/en_vivos.dart';
import '../features/teachers/presentation/perfil_docente_page.dart';
import '../features/teachers/presentation/seccion_clases_docentes.dart';
import '../features/teachers/presentation/solicitud_docente_page.dart';
import '../features/tutor/presentation/conversacion_tutor.dart';
import '../features/tutor/presentation/widgets/panel_tutor.dart';
import 'dependencias.dart';
import 'estudiante_shell.dart';
import 'inicio/contexto_academico.dart';
import 'inicio/inicio_page.dart';
import 'carga_arranque.dart';
import 'inicio/temas_por_reforzar.dart';
import '../features/seminars/presentation/seminarios_inicio.dart';
import '../features/student_model/domain/entities/actividad_alumno.dart';

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

  /// Si el puma del arranque ya terminó de formarse y se entró a la app.
  bool _entro = false;

  /// Veces que se preparó el plan en esta sesión: si después de prepararlo
  /// sigue sin aparecer, no se insiste (evita un ciclo sin fin).
  int _planesPreparados = 0;

  StreamSubscription<void>? _compras;

  @override
  void initState() {
    super.initState();
    _contextoAcademico = _cargarContextoAcademico();
    // Compras de Google Play que quedaron a medias: se activan al entrar y,
    // si activan Premium, se recarga el plan.
    if (_d.compraPlay case final compra?) {
      _compras = compra.activaciones.listen((_) {
        if (mounted) _recargar();
      });
      compra.revisarPendientes();
    }
    // Para el panel ("última actividad"). Si falla, no afecta al estudiante.
    widget.dependencias.actividad
        .registrar(widget.usuario.uid)
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _compras?.cancel();
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

  Future<ContextoAcademico?> _cargarContextoAcademico() async {
    final uid = widget.usuario.uid;
    // Para saber si el plan está en pausa. Si falla, se sigue sin eso.
    final premiumF = _d.premium
        .cargar(uid)
        .then<EstadoPremium?>((e) => e, onError: (Object _) => null);
    final contexto = await CargarContextoAcademicoService(
      matriculas: _d.matriculas,
      versiones: _d.versiones,
      planes: _d.planes,
      curriculoDe: _d.curriculoDe,
      ruta: _servicioRuta,
    ).cargar(usuarioId: uid, ahora: DateTime.now());
    final premium = await premiumF;
    final completo = contexto?.conPremium(
      premiumHasta: premium?.premiumHasta,
      pruebaHasta: premium?.pruebaHasta,
    );
    if (completo != null) _programarRecordatorios(completo);
    return completo;
  }

  /// Se pide permiso para notificar una vez por sesión.
  static bool _permisoPedido = false;

  /// Vuelve a programar los recordatorios del teléfono con lo de hoy (los
  /// anteriores se reemplazan). Si falla, la app sigue igual.
  void _programarRecordatorios(ContextoAcademico contexto) {
    final servicio = _d.recordatorios;
    if (servicio == null) return;
    final ahora = DateTime.now();
    final dia = contexto.diaEstudiante;
    final titulos = {for (final t in dia.temas) t.id: t.titulo};
    final matricula = contexto.matricula;
    final retomaEl = matricula.retomaEl;
    final lista = planificarRecordatorios(
      ahora: ahora,
      proximosDias: dia.proximosDias,
      tituloDe: (id) => titulos[id] ?? 'un tema nuevo',
      practicados: {for (final item in contexto.ruta) ?item.temaId},
      semana: dia.semana,
      pausa: contexto.pausa(ahora),
      retomaEl: retomaEl,
      semanaRetoma: retomaEl == null
          ? 0
          : semanaDelPlan(matricula.fechaInicioAcademico, retomaEl),
    );
    Future<void> programar() async {
      if (!_permisoPedido) {
        _permisoPedido = true;
        if (!await servicio.pedirPermiso()) return;
      }
      await servicio.programar(lista);
    }

    programar().catchError((Object _) {});
  }

  /// Premium (desde el perfil o el aviso de pausa). Al volver se recarga:
  /// si pagó, el plan retoma.
  Future<void> _abrirPremium() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PremiumPage(
          uid: widget.usuario.uid,
          nombre: widget.usuario.nombre,
          correo: widget.usuario.correo,
          repositorio: _d.premium,
          elegirFoto: _d.elegirFoto,
          compraPlay: _d.compraPlay,
        ),
      ),
    );
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContextoAcademico?>(
      future: _contextoAcademico,
      builder: (context, snapshot) {
        // Al recargar se mantiene lo anterior en pantalla (sin parpadeo).
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const CargaArranque();
        }

        // Ya están los datos: el puma termina de formarse y recién se entra.
        if (!_entro) {
          return CargaArranque(
            lista: true,
            alCompletar: () => setState(() => _entro = true),
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
          _PantallaAviso sinPlan(String mensaje, {VoidCallback? reintentar}) {
            return _PantallaAviso(
              titulo: 'Hola, ${widget.usuario.nombre}',
              mensaje: mensaje,
              onCerrarSesion: widget.onCerrarSesion,
              onReintentar: reintentar,
              // Un docente no necesita matrícula para pedir su cuenta ni
              // para enviar sus clases.
              onDocente: () => _abrirDocente(_d.temarioVigente),
              onEliminarCuenta: _d.eliminacion == null
                  ? null
                  : _abrirEliminarCuenta,
            );
          }

          // Recién registrado (o sin plan): se lo prepara solo.
          final preparacion = _d.preparacion;
          if (preparacion == null) {
            return sinPlan(
              'Tu cuenta está lista, pero todavía no tienes un plan activo. '
              'Cuando se active, aquí verás tus actividades del día.',
            );
          }
          if (_planesPreparados >= 2) {
            return sinPlan(
              'No pudimos abrir tu plan. Escríbenos para revisarlo.',
              reintentar: () {
                _planesPreparados = 0;
                _recargar();
              },
            );
          }
          return PrepararPlan(
            servicio: preparacion,
            nombre: widget.usuario.nombre,
            onListo: () {
              _planesPreparados++;
              _recargar();
            },
            siFalla: (mensaje, reintentar) =>
                sinPlan(mensaje, reintentar: reintentar),
          );
        }

        // Temas flojos por curso (BKT): resaltan los seminarios que ayudan.
        final porReforzar = temasPorReforzarPorCurso(
          contexto.ruta,
          contexto.curriculo,
        );

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
                inicioPlan: contexto.matricula.fechaInicioAcademico,
                retomaEl: contexto.matricula.retomaEl,
                pausa: contexto.pausa(DateTime.now()),
                onAbrirPremium: _abrirPremium,
                ruta: contexto.ruta,
                onAbrirTema: (tema, curso) => _abrirTema(contexto, tema, curso),
                onVerRuta: () => _pestana.value = 3,
                onAbrirPerfil: () => _pestana.value = 4,
                avisos: AvisosInicio(
                  repositorio: _d.avisos,
                  versionId: contexto.matricula.versionId,
                ),
                enVivos: SeccionEnVivos(
                  repositorio: _d.enVivos,
                  onVerDocente: _abrirPerfilDocente,
                  onReportar: (e) => _reportar(
                    context,
                    TipoReporte.claseDocente,
                    ContextoReporte(
                      titulo: 'En vivo de ${e.docenteNombre}: ${e.titulo}',
                    ),
                  ),
                ),
                examen: AvisoExamenSemanal(
                  servicio: _d.servicioExamenes,
                  onAbrir: () => _pestana.value = 2,
                ),
                seminarios: SeminariosInicio(
                  repositorio: _d.seminarios,
                  porReforzar: porReforzar,
                  onVerTodos: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SeminariosPage(
                        repositorio: _d.seminarios,
                        porReforzar: porReforzar,
                      ),
                    ),
                  ),
                ),
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
                onReportar: (context, examen, pregunta) => _reportar(
                  context,
                  TipoReporte.preguntaExamen,
                  ContextoReporte(
                    titulo: '${examen.titulo} · pregunta ${pregunta.numero}',
                    examenId: examen.id,
                    preguntaId: pregunta.id,
                  ),
                ),
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
                actividad: ActividadAlumno.desde(
                  fechas: contexto.actividad,
                  inicio: contexto.matricula.fechaInicioAcademico,
                  fin: contexto.matricula.fechaFin,
                  hoy: DateTime.now(),
                ),
                onAbrirPremium: _abrirPremium,
                onReportar: () => _reportar(
                  context,
                  TipoReporte.app,
                  const ContextoReporte(titulo: 'Desde el perfil'),
                ),
                onMisReportes: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MisReportesPage(
                      repositorio: _d.reportes,
                      uid: widget.usuario.uid,
                    ),
                  ),
                ),
                onDocente: () => _abrirDocente(
                  // Matriculado: su propio temario (ya está leído).
                  () async => contexto.curriculo,
                ),
                onEliminarCuenta: _d.eliminacion == null
                    ? null
                    : _abrirEliminarCuenta,
              ),
            ),
          ],
        );
      },
    );
  }

  void _abrirEliminarCuenta() {
    final servicio = _d.eliminacion;
    if (servicio == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EliminarCuentaPage(
          servicio: servicio,
          cargarPremium: () => _d.premium.cargar(widget.usuario.uid),
          onEliminada: widget.onCerrarSesion,
        ),
      ),
    );
  }

  void _abrirDocente(Future<Curriculo?> Function() temario) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SolicitudDocentePage(
          uid: widget.usuario.uid,
          nombre: widget.usuario.nombre,
          correo: widget.usuario.correo,
          repositorio: _d.docentes,
          clases: _d.clasesDocentes,
          temario: temario,
          enVivos: _d.enVivos,
        ),
      ),
    );
  }

  void _abrirPerfilDocente(String docenteUid, String nombre) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PerfilDocentePage(
          docenteUid: docenteUid,
          nombre: nombre,
          uid: widget.usuario.uid,
          docentes: _d.docentes,
          clases: _d.clasesDocentes,
          enVivos: _d.enVivos,
          onReportarClase: _reportarClase,
        ),
      ),
    );
  }

  void _reportarClase(ClaseDocente clase, {String? versionId}) => _reportar(
    context,
    TipoReporte.claseDocente,
    ContextoReporte(
      titulo: 'Clase de ${clase.docenteNombre}: ${clase.titulo}',
      versionId: versionId,
      temaId: versionId == null ? null : clase.temaId,
      claseId: clase.id,
    ),
  );

  void _reportar(
    BuildContext context,
    TipoReporte tipo,
    ContextoReporte contexto,
  ) {
    mostrarReportar(
      context,
      repositorio: _d.reportes,
      autor: AutorReporte(
        uid: widget.usuario.uid,
        nombre: widget.usuario.nombre,
        correo: widget.usuario.correo,
      ),
      tipo: tipo,
      contexto: contexto,
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
          preguntasVideo: _d.preguntasVideo,
          practica: (claseVista) => SeccionPracticaTema(
            service: practica,
            temaId: tema.id,
            versionId: versionId,
            tituloTema: tema.titulo,
            claseVista: claseVista,
          ),
          onReportar: () => _reportar(
            context,
            TipoReporte.video,
            ContextoReporte(
              titulo: [?curso?.nombre, tema.titulo].join(' · '),
              versionId: versionId,
              temaId: tema.id,
            ),
          ),
          narraciones: (pausarClase) => SeccionNarraciones(
            repositorio: _d.narraciones,
            versionId: versionId,
            temaId: tema.id,
            alReproducir: pausarClase,
          ),
          clasesDocentes: (pausarClase) => SeccionClasesDocentes(
            repositorio: _d.clasesDocentes,
            temaId: tema.id,
            uid: widget.usuario.uid,
            alAbrir: pausarClase,
            onVerDocente: _abrirPerfilDocente,
            onReportar: (clase) => _reportarClase(clase, versionId: versionId),
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

  /// "¿Eres docente?" (solo cuando no tiene matrícula).
  final VoidCallback? onDocente;

  /// "Eliminar mi cuenta": también sin matrícula se puede borrar.
  final VoidCallback? onEliminarCuenta;

  /// "Reintentar" (cuando no se pudo preparar el plan).
  final VoidCallback? onReintentar;

  const _PantallaAviso({
    required this.titulo,
    required this.mensaje,
    required this.onCerrarSesion,
    this.onDocente,
    this.onEliminarCuenta,
    this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sinchi')),
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
                if (onReintentar != null) ...[
                  FilledButton.icon(
                    onPressed: onReintentar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (onDocente != null) ...[
                  FilledButton.icon(
                    onPressed: onDocente,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('¿Eres docente? Entra aquí'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: onCerrarSesion,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
                if (onEliminarCuenta != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onEliminarCuenta,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade300,
                    ),
                    child: const Text('Eliminar mi cuenta'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
