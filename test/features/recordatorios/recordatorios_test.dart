import 'package:academiapp_v2/features/academic/domain/entities/actividad_programada.dart';
import 'package:academiapp_v2/features/academic/domain/entities/dia_academico.dart';
import 'package:academiapp_v2/features/academic/domain/entities/semana_plan.dart';
import 'package:academiapp_v2/features/enrollment/domain/pausa_plan.dart';
import 'package:academiapp_v2/features/recordatorios/domain/recordatorios.dart';
import 'package:flutter_test/flutter_test.dart';

DiaAcademico dia(DateTime fecha, List<String> temas) => DiaAcademico(
  numero: fecha.day,
  fecha: fecha,
  actividades: [
    for (final (i, t) in temas.indexed)
      ActividadProgramada(id: '$t-$i', diaId: 'd', temaId: t, orden: i + 1),
  ],
);

String titulo(String id) => 'Tema $id';

void main() {
  // Miércoles 25 de noviembre de 2026, 10 a. m.
  final ahora = DateTime(2026, 11, 25, 10);
  final semana = SemanaPlan(
    numero: 3,
    temaIds: const ['a', 'b', 'c'],
    sabado: DateTime(2026, 11, 28),
  );
  final proximos = [
    dia(DateTime(2026, 11, 25), ['a', 'b', 'c']),
    dia(DateTime(2026, 11, 26), ['d']),
    dia(DateTime(2026, 11, 27), const []),
  ];

  test('plan andando: temas del día, lo que falta hoy y el examen', () {
    final r = planificarRecordatorios(
      ahora: ahora,
      proximosDias: proximos,
      tituloDe: titulo,
      practicados: {'a'},
      semana: semana,
    );
    expect(r.map((x) => (x.id, x.cuando, x.titulo)), [
      (10, DateTime(2026, 11, 25, 20), 'Te faltan 2 temas de hoy'),
      (2, DateTime(2026, 11, 26, 7), 'Hoy te toca 1 tema'),
      (20, DateTime(2026, 11, 28, 9), 'Ya puedes dar tu examen de la semana 3'),
    ]);
    // El de hoy a las 7 a. m. ya pasó; el día sin temas no avisa; el examen
    // del otro sábado se programa cuando falte menos de una semana.
    expect(r.any((x) => x.id == 1), isFalse);
    expect(r.any((x) => x.id == 3), isFalse);
  });

  test('temprano avisa los temas de hoy con sus nombres', () {
    final r = planificarRecordatorios(
      ahora: DateTime(2026, 11, 25, 6),
      proximosDias: proximos,
      tituloDe: titulo,
      practicados: const {},
    );
    final hoy = r.firstWhere((x) => x.id == 1);
    expect(hoy.titulo, 'Hoy te tocan 3 temas');
    expect(hoy.cuerpo, 'Tema a, Tema b y Tema c');
  });

  test('si ya hizo los de hoy, no le recuerda lo que falta', () {
    final r = planificarRecordatorios(
      ahora: ahora,
      proximosDias: proximos,
      tituloDe: titulo,
      practicados: {'a', 'b', 'c'},
    );
    expect(r.any((x) => x.id == 10), isFalse);
  });

  test('en pausa: un solo aviso amable dos días después', () {
    final r = planificarRecordatorios(
      ahora: ahora,
      proximosDias: proximos,
      tituloDe: titulo,
      practicados: const {},
      semana: semana,
      pausa: PausaPlan(
        desde: DateTime(2026, 11, 23),
        semana: 3,
        eraPrueba: true,
      ),
    );
    expect(r.length, 1);
    expect(r.single.cuando, DateTime(2026, 11, 27, 19));
    expect(r.single.titulo, 'Tu plan te espera en la semana 3');
  });

  test('ya pagó: avisa el lunes en que retoma y nada antes', () {
    final r = planificarRecordatorios(
      ahora: ahora,
      proximosDias: [...proximos, dia(DateTime(2026, 11, 30), ['e', 'f'])],
      tituloDe: titulo,
      practicados: const {},
      semana: semana,
      retomaEl: DateTime(2026, 11, 30),
      semanaRetoma: 3,
    );
    expect(r.map((x) => (x.id, x.cuando)), [
      (6, DateTime(2026, 11, 30, 7)),
      (40, DateTime(2026, 11, 30, 7)),
    ]);
    expect(r.last.cuerpo, 'Sigues con la semana 3. ¡Vamos!');
  });

  test('el examen del sábado siguiente entra cuando falta una semana', () {
    final r = planificarRecordatorios(
      ahora: DateTime(2026, 11, 28, 10),
      proximosDias: const [],
      tituloDe: titulo,
      practicados: const {},
      semana: semana,
    );
    expect(r.map((x) => (x.id, x.cuando)), [(21, DateTime(2026, 12, 5, 9))]);
  });
}
