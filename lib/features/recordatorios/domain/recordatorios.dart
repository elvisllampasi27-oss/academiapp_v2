import '../../academic/domain/entities/dia_academico.dart';
import '../../academic/domain/entities/semana_plan.dart';
import '../../enrollment/domain/pausa_plan.dart';

/// Una notificación programada en el teléfono.
class Recordatorio {
  final int id;
  final DateTime cuando;
  final String titulo;
  final String cuerpo;

  const Recordatorio({
    required this.id,
    required this.cuando,
    required this.titulo,
    required this.cuerpo,
  });

  @override
  String toString() => '$id ${cuando.toIso8601String()} $titulo · $cuerpo';
}

/// Programa los recordatorios en el teléfono (reemplaza los anteriores).
abstract class ServicioRecordatorios {
  /// Pide permiso para notificar (Android 13+). Devuelve si lo tiene.
  Future<bool> pedirPermiso();

  Future<void> programar(List<Recordatorio> recordatorios);
}

// Horas de Perú.
const horaTemasDelDia = 7;
const horaLoQueFalta = 20;
const horaExamen = 9;
const horaPausa = 19;

/// Ids fijos: al volver a programar se reemplazan, no se duplican.
const _idDia = 1; // 1…7
const _idLoQueFalta = 10;
const _idExamen = 20; // 20 y 21
const _idPausa = 30;
const _idRetoma = 40;

DateTime _a(DateTime dia, int hora) =>
    DateTime(dia.year, dia.month, dia.day, hora);

/// "A, B y C".
String _lista(List<String> textos) => switch (textos.length) {
  0 => '',
  1 => textos.first,
  _ =>
    '${textos.sublist(0, textos.length - 1).join(', ')} y ${textos.last}',
};

/// Qué recordatorios programar al abrir la app. Se vuelven a calcular cada
/// vez que se recarga el inicio, así siguen lo que el alumno ya hizo.
///
/// - Con su plan andando: a las 7 a. m. los temas de cada día (7 días), a
///   las 8 p. m. de hoy los temas que le faltan, y el sábado a las 9 a. m.
///   que ya puede dar su examen.
/// - Con el plan en pausa: un solo aviso amable dos días después.
/// - Si ya pagó y retoma el lunes: ese lunes a las 7 a. m.
List<Recordatorio> planificarRecordatorios({
  required DateTime ahora,
  required List<DiaAcademico> proximosDias,
  required String Function(String temaId) tituloDe,
  required Set<String> practicados,
  SemanaPlan? semana,
  PausaPlan? pausa,
  DateTime? retomaEl,
  int semanaRetoma = 0,
}) {
  final lista = <Recordatorio>[];
  void agregar(int id, DateTime cuando, String titulo, String cuerpo) {
    if (cuando.isAfter(ahora)) {
      lista.add(
        Recordatorio(id: id, cuando: cuando, titulo: titulo, cuerpo: cuerpo),
      );
    }
  }

  if (pausa != null) {
    final dia = DateTime(ahora.year, ahora.month, ahora.day + 2);
    agregar(
      _idPausa,
      _a(dia, horaPausa),
      'Tu plan te espera en la semana ${pausa.semana}',
      'Retómalo cuando quieras: vuelves desde el lunes sin perder lo que '
          'avanzaste.',
    );
    return lista;
  }

  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final retoma = retomaEl == null
      ? null
      : DateTime(retomaEl.year, retomaEl.month, retomaEl.day);
  // Ya pagó y retoma un lunes que todavía no llega.
  final esperaHasta = retoma != null && retoma.isAfter(hoy) ? retoma : null;
  if (esperaHasta != null) {
    agregar(
      _idRetoma,
      _a(esperaHasta, horaTemasDelDia),
      'Hoy retomas tu plan',
      semanaRetoma > 0
          ? 'Sigues con la semana $semanaRetoma. ¡Vamos!'
          : 'Ya tienes tus temas del día.',
    );
  }

  for (final dia in proximosDias) {
    final fecha = dia.fecha;
    if (fecha == null || dia.actividades.isEmpty) continue;
    final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
    // Antes del lunes en que retoma, el calendario no es el suyo.
    if (esperaHasta != null && soloFecha.isBefore(esperaHasta)) continue;
    final offset = soloFecha.difference(hoy).inDays;
    if (offset < 0 || offset > 6) continue;
    final temas = [for (final a in dia.actividades) tituloDe(a.temaId)];
    agregar(
      _idDia + offset,
      _a(soloFecha, horaTemasDelDia),
      temas.length == 1 ? 'Hoy te toca 1 tema' : 'Hoy te tocan ${temas.length} temas',
      _lista(temas),
    );
    if (offset == 0) {
      final faltan = dia.actividades
          .where((a) => !practicados.contains(a.temaId))
          .length;
      if (faltan > 0) {
        agregar(
          _idLoQueFalta,
          _a(soloFecha, horaLoQueFalta),
          faltan == 1
              ? 'Te falta 1 tema de hoy'
              : 'Te faltan $faltan temas de hoy',
          'Unos minutos ahora y mañana empiezas al día.',
        );
      }
    }
  }

  if (semana != null && esperaHasta == null) {
    for (var i = 0; i < 2; i++) {
      final sabado = DateTime(
        semana.sabado.year,
        semana.sabado.month,
        semana.sabado.day + 7 * i,
      );
      if (sabado.difference(hoy).inDays > 7) continue;
      agregar(
        _idExamen + i,
        _a(sabado, horaExamen),
        'Ya puedes dar tu examen de la semana ${semana.numero + i}',
        'Tienes hasta el viernes. Es un solo intento.',
      );
    }
  }

  lista.sort((a, b) {
    final porHora = a.cuando.compareTo(b.cuando);
    return porHora != 0 ? porHora : a.id.compareTo(b.id);
  });
  return lista;
}
