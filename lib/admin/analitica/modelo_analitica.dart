import '../../features/premium/domain/pago.dart';
import '../estudiantes/modelo_estudiantes.dart';

/// Cifras de la pantalla Analítica (Dart puro, probado en test/admin).

/// Primer día de los últimos [n] meses, del más antiguo al actual.
List<DateTime> ultimosMeses(DateTime hoy, int n) => [
  for (var i = n - 1; i >= 0; i--) DateTime(hoy.year, hoy.month - i),
];

bool _mismoMes(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// Soles cobrados por mes (pagos aprobados; la fecha es cuando se aprobó).
List<(DateTime, int)> ingresosPorMes(
  List<Pago> pagos,
  DateTime hoy, {
  int meses = 6,
}) => [
  for (final mes in ultimosMeses(hoy, meses))
    (
      mes,
      pagos
          .where(
            (p) =>
                p.estado == EstadoPago.aprobado &&
                _mismoMes(p.revisadoEn ?? p.creadoEn, mes),
          )
          .fold<int>(0, (suma, p) => suma + p.monto),
    ),
];

/// Estudiantes que se registraron cada mes.
List<(DateTime, int)> registrosPorMes(
  List<EstudianteAdmin> estudiantes,
  DateTime hoy, {
  int meses = 6,
}) => [
  for (final mes in ultimosMeses(hoy, meses))
    (
      mes,
      estudiantes
          .where((e) => e.registro != null && _mismoMes(e.registro!, mes))
          .length,
    ),
];

/// Carreras con más estudiantes; el resto va junto en "Otras".
List<(String, int)> porCarrera(
  List<EstudianteAdmin> estudiantes, {
  int maximo = 6,
}) {
  final cuenta = <String, int>{};
  for (final e in estudiantes) {
    final carrera = (e.carrera ?? '').trim();
    final clave = carrera.isEmpty ? 'Sin carrera' : carrera;
    cuenta[clave] = (cuenta[clave] ?? 0) + 1;
  }
  final orden = cuenta.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  if (orden.length <= maximo) {
    return [for (final e in orden) (e.key, e.value)];
  }
  final resto = orden
      .skip(maximo - 1)
      .fold<int>(0, (suma, e) => suma + e.value);
  return [
    for (final e in orden.take(maximo - 1)) (e.key, e.value),
    ('Otras', resto),
  ];
}

Map<SituacionEstudiante, int> porSituacion(
  List<EstudianteAdmin> estudiantes,
  DateTime hoy,
) {
  final cuenta = {for (final s in SituacionEstudiante.values) s: 0};
  for (final e in estudiantes) {
    final s = situacion(e, hoy);
    cuenta[s] = cuenta[s]! + 1;
  }
  return cuenta;
}

/// De los matriculados activos, qué parte abrió la app en los últimos
/// [dias] días. null si no hay activos.
double? retencion(
  List<EstudianteAdmin> estudiantes,
  DateTime hoy, {
  int dias = 7,
}) {
  final activos = [
    for (final e in estudiantes)
      if (situacion(e, hoy) == SituacionEstudiante.activo) e,
  ];
  if (activos.isEmpty) return null;
  final desde = DateTime(hoy.year, hoy.month, hoy.day - (dias - 1));
  final volvieron = activos
      .where((e) => e.ultimaActividad?.isBefore(desde) == false)
      .length;
  return volvieron / activos.length;
}

/// Variación entre el último valor y el anterior: "+12 %", "−5 %", "nuevo"
/// o null si no hay con qué comparar.
String? variacion(List<(DateTime, int)> serie) {
  if (serie.length < 2) return null;
  final actual = serie.last.$2;
  final anterior = serie[serie.length - 2].$2;
  if (anterior == 0) return actual == 0 ? null : 'nuevo';
  final cambio = ((actual - anterior) * 100 / anterior).round();
  return cambio >= 0 ? '+$cambio %' : '−${-cambio} %';
}
