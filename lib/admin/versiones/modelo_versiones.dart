import '../../features/academic/domain/entities/curriculo.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../../features/academic/domain/services/calendario_academico_service.dart';
import '../../features/academic/domain/services/secuencia_academica_service.dart';
import '../../features/enrollment/domain/entities/matricula.dart';
import '../estudiantes/modelo_estudiantes.dart';

/// Reglas de la pantalla Versiones (Dart puro, probadas en test/admin).

extension EtiquetaEstadoVersion on EstadoVersionAcademica {
  String get etiqueta => switch (this) {
    EstadoVersionAcademica.preparacion => 'Preparación',
    EstadoVersionAcademica.publicada => 'Publicada',
    EstadoVersionAcademica.activa => 'Activa',
    EstadoVersionAcademica.cerradaNuevasMatriculas =>
      'Cerrada a nuevas matrículas',
    EstadoVersionAcademica.finalizada => 'Finalizada',
    EstadoVersionAcademica.archivada => 'Archivada',
  };

  String get explicacion => switch (this) {
    EstadoVersionAcademica.preparacion =>
      'Se arma el temario; nadie puede matricularse todavía.',
    EstadoVersionAcademica.publicada =>
      'Ya acepta matrículas; el ciclo aún no empieza.',
    EstadoVersionAcademica.activa => 'En curso y aceptando matrículas.',
    EstadoVersionAcademica.cerradaNuevasMatriculas =>
      'Sigue en curso, pero no acepta matrículas nuevas.',
    EstadoVersionAcademica.finalizada =>
      'Terminó; los estudiantes conservan su historial.',
    EstadoVersionAcademica.archivada => 'Oculta de las listas del panel.',
  };
}

/// Estudiantes con matrícula vigente en una versión, por situación.
class ConteoVersion {
  final int activos;
  final int programados;
  final int suspendidos;

  const ConteoVersion(this.activos, this.programados, this.suspendidos);

  int get total => activos + programados + suspendidos;
}

ConteoVersion contarVersion(
  String versionId,
  List<EstudianteAdmin> estudiantes,
  DateTime hoy,
) {
  var a = 0, p = 0, s = 0;
  for (final e in estudiantes) {
    if (e.matricula?.versionId != versionId) continue;
    switch (situacion(e, hoy)) {
      case SituacionEstudiante.activo:
        a++;
      case SituacionEstudiante.programado:
        p++;
      case SituacionEstudiante.suspendido:
        s++;
      default:
        break;
    }
  }
  return ConteoVersion(a, p, s);
}

/// Inicio del estudiante más adelantado de la versión (el que empezó
/// primero y sigue activo). Con él se decide hasta dónde publicar.
DateTime? inicioMasAdelantado(String versionId, List<EstudianteAdmin> lista) {
  DateTime? inicio;
  for (final e in lista) {
    final m = e.matricula;
    if (m == null ||
        m.versionId != versionId ||
        m.estado != EstadoMatricula.activa) {
      continue;
    }
    if (inicio == null || m.fechaInicioAcademico.isBefore(inicio)) {
      inicio = m.fechaInicioAcademico;
    }
  }
  return inicio;
}

/// Un día del calendario con sus temas (ids, en orden).
class DiaVersion {
  final int numero;
  final DateTime fecha;
  final List<String> temas;

  const DiaVersion(this.numero, this.fecha, this.temas);
}

/// Calendario de la versión contando desde [inicio]: lunes a viernes 3
/// temas, sábado 2, domingo libre (el mismo servicio que usa la app).
List<DiaVersion> calendarioVersion(Curriculo curriculo, DateTime inicio) {
  final secuencia = const SecuenciaAcademicaService().generar(
    cursos: curriculo.cursos.where((c) => c.activo).toList(),
    temas: curriculo.temas,
  );
  return [
    for (final d in const CalendarioAcademicoService().generar(
      secuencia: secuencia,
      fechaInicio: inicio,
    ))
      DiaVersion(d.numero, d.fecha!, [for (final a in d.actividades) a.temaId]),
  ];
}

enum EstadoDia {
  /// El más adelantado ya llegó y está publicado.
  alcanzado,

  /// Publicado por adelantado.
  adelantado,

  /// Todavía sin publicar.
  pendiente,

  /// El más adelantado ya llegó y NO está publicado: hay que publicar.
  atrasado,
}

EstadoDia estadoDia(DiaVersion dia, int diaActual, Set<String> publicados) {
  final publicado = dia.temas.every(publicados.contains);
  if (dia.numero <= diaActual) {
    return publicado ? EstadoDia.alcanzado : EstadoDia.atrasado;
  }
  return publicado ? EstadoDia.adelantado : EstadoDia.pendiente;
}

/// Último día publicado completo (0 si ninguno).
int ultimoDiaPublicado(List<DiaVersion> dias, Set<String> publicados) {
  var ultimo = 0;
  for (final d in dias) {
    if (!d.temas.every(publicados.contains)) break;
    ultimo = d.numero;
  }
  return ultimo;
}

/// Temas a publicar para llegar al día [hasta] (los que faltan).
List<String> temasPorPublicar(
  List<DiaVersion> dias,
  int hasta,
  Set<String> publicados,
) => [
  for (final d in dias.where((d) => d.numero <= hasta))
    for (final t in d.temas)
      if (!publicados.contains(t)) t,
];

/// Cuántos estudiantes empezaron cada día (los más comunes primero).
List<(DateTime, int)> iniciosPorFecha(
  String versionId,
  List<EstudianteAdmin> lista,
) {
  final conteo = <DateTime, int>{};
  for (final e in lista) {
    final m = e.matricula;
    if (m == null ||
        m.versionId != versionId ||
        m.estado == EstadoMatricula.finalizada) {
      continue;
    }
    final f = m.fechaInicioAcademico;
    final dia = DateTime(f.year, f.month, f.day);
    conteo[dia] = (conteo[dia] ?? 0) + 1;
  }
  return conteo.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
}

/// "Ciclo 2027-I" -> "ciclo-2027-i" (id del documento de la versión).
String idDesdeNombre(String nombre) {
  const conTilde = 'áéíóúüñ';
  const sinTilde = 'aeiouun';
  final buffer = StringBuffer();
  for (final c in nombre.toLowerCase().trim().split('')) {
    final i = conTilde.indexOf(c);
    buffer.write(i >= 0 ? sinTilde[i] : c);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Id de un documento copiado a otra versión: "version-1__x" ->
/// "ciclo-2027-i__x".
String idEnVersion(String id, String origen, String destino) =>
    id.startsWith('${origen}__')
    ? '${destino}__${id.substring(origen.length + 2)}'
    : '${destino}__$id';
