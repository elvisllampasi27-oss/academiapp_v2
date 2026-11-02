import '../../core/presentation/texto.dart';
import '../../features/academic/domain/entities/curriculo.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../../features/academic/domain/services/calendario_academico_service.dart';
import '../../features/academic/domain/services/secuencia_academica_service.dart';
import '../../features/adaptive_engine/domain/entities/item_mi_ruta.dart';
import '../../features/enrollment/domain/entities/configuracion_inicio.dart';
import '../../features/enrollment/domain/entities/matricula.dart';

/// Estudiante tal como lo ve el panel: su cuenta y su matrícula vigente.
class EstudianteAdmin {
  final String uid;
  final String nombre;
  final String correo;
  final String? carrera;
  final DateTime? registro;
  final DateTime? ultimaActividad;
  final Matricula? matricula;

  const EstudianteAdmin({
    required this.uid,
    required this.nombre,
    required this.correo,
    this.carrera,
    this.registro,
    this.ultimaActividad,
    this.matricula,
  });
}

/// Lo que hizo el administrador desde el panel (colección registro_admin).
class AccionAdmin {
  final String tipo;
  final String descripcion;
  final String? usuarioId;
  final String adminCorreo;
  final DateTime fecha;

  const AccionAdmin({
    required this.tipo,
    required this.descripcion,
    required this.adminCorreo,
    required this.fecha,
    this.usuarioId,
  });
}

class SimulacroAdmin {
  final DateTime fecha;
  final int correctas;
  final int total;
  final int segundos;

  const SimulacroAdmin({
    required this.fecha,
    required this.correctas,
    required this.total,
    required this.segundos,
  });
}

class DominioCurso {
  final String curso;
  final double valor;
  const DominioCurso(this.curso, this.valor);
}

class TemaReforzar {
  final String tema;
  final double valor;
  const TemaReforzar(this.tema, this.valor);
}

/// Todo lo que muestra la ficha de un estudiante.
class FichaEstudiante {
  final EstudianteAdmin estudiante;
  final List<Matricula> matriculas;
  final VersionAcademica? version;
  final FinTemario? fin;
  final int clasesCompletas;
  final int totalTemas;
  final int respuestas;
  final int correctas;
  final List<SimulacroAdmin> simulacros;
  final List<DominioCurso> dominio;
  final List<TemaReforzar> reforzar;
  final List<AccionAdmin> acciones;

  const FichaEstudiante({
    required this.estudiante,
    required this.matriculas,
    required this.version,
    required this.fin,
    required this.clasesCompletas,
    required this.totalTemas,
    required this.respuestas,
    required this.correctas,
    required this.simulacros,
    required this.dominio,
    required this.reforzar,
    required this.acciones,
  });
}

// ------------------------------------------------------------------
// Reglas del panel (Dart puro, probadas en test/admin).
// ------------------------------------------------------------------

/// Matricularse después de esta hora empieza al día siguiente.
const configuracionInicioPanel = ConfiguracionInicio(
  horaInicio: 0,
  horaCorte: 18,
);

/// Días sin entrar a la app para avisar.
const diasSinActividad = 5;

enum SituacionEstudiante {
  activo,
  programado,
  suspendido,
  finalizado,
  sinMatricula,
}

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

SituacionEstudiante situacion(EstudianteAdmin e, DateTime hoy) {
  final m = e.matricula;
  if (m == null) return SituacionEstudiante.sinMatricula;
  return switch (m.estado) {
    EstadoMatricula.suspendida => SituacionEstudiante.suspendido,
    EstadoMatricula.finalizada => SituacionEstudiante.finalizado,
    _ =>
      _dia(m.fechaInicioAcademico).isAfter(_dia(hoy))
          ? SituacionEstudiante.programado
          : SituacionEstudiante.activo,
  };
}

/// Día académico de hoy (los domingos no cuentan). 0 si aún no empieza.
int diaAcademico(DateTime inicio, DateTime hoy) {
  var fecha = _dia(inicio);
  final fin = _dia(hoy);
  var dias = 0;
  while (!fecha.isAfter(fin)) {
    if (fecha.weekday != DateTime.sunday) dias++;
    fecha = DateTime(fecha.year, fecha.month, fecha.day + 1);
  }
  return dias;
}

/// Activo que lleva [diasSinActividad] días o más sin abrir la app.
bool sinActividad(EstudianteAdmin e, DateTime hoy) {
  if (situacion(e, hoy) != SituacionEstudiante.activo) return false;
  final desde = e.ultimaActividad ?? e.matricula!.fechaInicioAcademico;
  return _dia(hoy).difference(_dia(desde)).inDays >= diasSinActividad;
}

/// De todas las matrículas de un estudiante, la que importa: la activa,
/// luego la suspendida y, si no, la más reciente.
Matricula? matriculaVigente(List<Matricula> matriculas) {
  if (matriculas.isEmpty) return null;
  int peso(Matricula m) => switch (m.estado) {
    EstadoMatricula.activa => 0,
    EstadoMatricula.programada => 1,
    EstadoMatricula.suspendida => 2,
    EstadoMatricula.finalizada => 3,
  };
  final orden = [...matriculas]
    ..sort((a, b) {
      final porEstado = peso(a).compareTo(peso(b));
      return porEstado != 0
          ? porEstado
          : b.fechaMatricula.compareTo(a.fechaMatricula);
    });
  return orden.first;
}

enum FiltroEstudiantes {
  todos('Todos'),
  activos('Activos'),
  programados('Programados'),
  suspendidos('Suspendidos'),
  sinMatricula('Registrados sin matrícula'),
  sinActividad('Sin actividad $diasSinActividad+ días');

  final String etiqueta;
  const FiltroEstudiantes(this.etiqueta);
}

List<EstudianteAdmin> filtrarEstudiantes(
  List<EstudianteAdmin> lista, {
  required DateTime hoy,
  FiltroEstudiantes filtro = FiltroEstudiantes.todos,
  String texto = '',
  String? versionId,
}) {
  final buscado = normalizarTexto(texto.trim());
  return lista.where((e) {
    if (versionId != null && e.matricula?.versionId != versionId) {
      return false;
    }
    if (buscado.isNotEmpty &&
        !normalizarTexto('${e.nombre} ${e.correo}').contains(buscado)) {
      return false;
    }
    final s = situacion(e, hoy);
    return switch (filtro) {
      FiltroEstudiantes.todos => true,
      FiltroEstudiantes.activos => s == SituacionEstudiante.activo,
      FiltroEstudiantes.programados => s == SituacionEstudiante.programado,
      FiltroEstudiantes.suspendidos => s == SituacionEstudiante.suspendido,
      FiltroEstudiantes.sinMatricula => s == SituacionEstudiante.sinMatricula,
      FiltroEstudiantes.sinActividad => sinActividad(e, hoy),
    };
  }).toList()..sort(
    (a, b) => normalizarTexto(a.nombre).compareTo(normalizarTexto(b.nombre)),
  );
}

/// Cifras de la pantalla Resumen.
class ResumenPanel {
  final int activos;
  final int programados;
  final int sinMatricula;
  final int activosHoy;
  final int nuevasEstaSemana;
  final List<EstudianteAdmin> sinActividad;

  /// Matrículas por semana (lunes de cada semana), de la más antigua a hoy.
  final List<(DateTime, int)> porSemana;

  const ResumenPanel({
    required this.activos,
    required this.programados,
    required this.sinMatricula,
    required this.activosHoy,
    required this.nuevasEstaSemana,
    required this.sinActividad,
    required this.porSemana,
  });
}

DateTime lunesDe(DateTime fecha) {
  final d = _dia(fecha);
  return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}

ResumenPanel calcularResumen(
  List<EstudianteAdmin> lista,
  DateTime hoy, {
  int semanas = 6,
}) {
  final situaciones = [for (final e in lista) situacion(e, hoy)];
  int contar(SituacionEstudiante s) => situaciones.where((x) => x == s).length;

  final lunesActual = lunesDe(hoy);
  final inicios = [
    for (var i = semanas - 1; i >= 0; i--)
      DateTime(lunesActual.year, lunesActual.month, lunesActual.day - 7 * i),
  ];
  final conteo = {for (final l in inicios) l: 0};
  for (final e in lista) {
    final m = e.matricula;
    if (m == null) continue;
    final semana = lunesDe(m.fechaMatricula);
    if (conteo.containsKey(semana)) conteo[semana] = conteo[semana]! + 1;
  }

  return ResumenPanel(
    activos: contar(SituacionEstudiante.activo),
    programados: contar(SituacionEstudiante.programado),
    sinMatricula: contar(SituacionEstudiante.sinMatricula),
    activosHoy: lista.where((e) {
      final u = e.ultimaActividad;
      return u != null && _dia(u) == _dia(hoy);
    }).length,
    nuevasEstaSemana: conteo[lunesActual] ?? 0,
    sinActividad: lista.where((e) => sinActividad(e, hoy)).toList(),
    porSemana: [for (final l in inicios) (l, conteo[l]!)],
  );
}

/// Actividad de un día: prácticas resueltas y exámenes tipo admisión.
class ActividadDia {
  final DateTime dia;
  final int practicas;
  final int simulacros;

  const ActividadDia(this.dia, this.practicas, this.simulacros);
}

/// Cuenta por día los últimos [dias] días (hoy incluido), con ceros en los
/// días sin actividad.
List<ActividadDia> agruparActividad({
  required List<DateTime> practicas,
  required List<DateTime> simulacros,
  required DateTime hoy,
  int dias = 14,
}) {
  final base = _dia(hoy);
  final indice = <DateTime, int>{
    for (var i = 0; i < dias; i++)
      DateTime(base.year, base.month, base.day - (dias - 1 - i)): i,
  };
  final p = List.filled(dias, 0);
  final s = List.filled(dias, 0);
  for (final f in practicas) {
    if (indice[_dia(f)] case final i?) p[i]++;
  }
  for (final f in simulacros) {
    if (indice[_dia(f)] case final i?) s[i]++;
  }
  return [
    for (final MapEntry(key: dia, value: i) in indice.entries)
      ActividadDia(dia, p[i], s[i]),
  ];
}

/// Cuándo termina el temario de una versión si se empieza en [inicio].
class FinTemario {
  final int dias;
  final int temas;
  final DateTime fecha;
  const FinTemario({
    required this.dias,
    required this.temas,
    required this.fecha,
  });
}

FinTemario? finTemario(Curriculo curriculo, DateTime inicio) {
  final secuencia = const SecuenciaAcademicaService().generar(
    cursos: curriculo.cursos.where((c) => c.activo).toList(),
    temas: curriculo.temas,
  );
  final dias = const CalendarioAcademicoService().generar(
    secuencia: secuencia,
    fechaInicio: inicio,
  );
  final ultimo = dias.lastOrNull?.fecha;
  if (ultimo == null) return null;
  return FinTemario(dias: dias.length, temas: secuencia.length, fecha: ultimo);
}

/// Dominio promedio por curso y los temas más flojos, a partir de la ruta
/// del estudiante (BKT).
(List<DominioCurso>, List<TemaReforzar>) dominioDe(
  List<ItemMiRuta> ruta,
  Curriculo curriculo,
) {
  final temas = {for (final t in curriculo.temas) t.id: t};
  final porCurso = <String, List<double>>{};
  final flojos = <TemaReforzar>[];

  for (final item in ruta) {
    final tema = temas[item.temaId];
    if (tema == null) continue;
    porCurso.putIfAbsent(tema.cursoId, () => []).add(item.estado.valor);
    if (item.estado.valor < 0.5) {
      flojos.add(TemaReforzar(tema.titulo, item.estado.valor));
    }
  }

  final cursos = [...curriculo.cursos]
    ..sort((a, b) => a.orden.compareTo(b.orden));
  final dominio = [
    for (final c in cursos)
      if (porCurso[c.id] case final valores?)
        DominioCurso(
          c.nombre,
          valores.reduce((a, b) => a + b) / valores.length,
        ),
  ];
  flojos.sort((a, b) => a.valor.compareTo(b.valor));
  return (dominio, flojos.take(5).toList());
}

// ------------------------------------------------------------------
// Fechas como se leen en el panel.
// ------------------------------------------------------------------

const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'set',
  'oct',
  'nov',
  'dic',
];

/// "jue 23 oct 2026".
String fechaPanel(DateTime f) =>
    '${_diasCortos[f.weekday - 1]} ${f.day} ${_meses[f.month - 1]} ${f.year}';

/// "23 oct".
String fechaBreve(DateTime f) => '${f.day} ${_meses[f.month - 1]}';

/// "Hoy, 10:42", "Ayer", "Hace 6 días", "23 oct" o "—".
String haceCuanto(DateTime? f, DateTime ahora) {
  if (f == null) return '—';
  final dias = _dia(ahora).difference(_dia(f)).inDays;
  if (dias <= 0) {
    final m = f.minute.toString().padLeft(2, '0');
    return 'Hoy, ${f.hour}:$m';
  }
  if (dias == 1) return 'Ayer';
  if (dias < 30) return 'Hace $dias días';
  return fechaBreve(f);
}
