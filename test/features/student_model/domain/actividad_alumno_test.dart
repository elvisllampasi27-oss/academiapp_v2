import 'package:academiapp_v2/features/student_model/domain/entities/actividad_alumno.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final inicio = DateTime(2026, 11, 2); // lunes
  final fin = DateTime(2026, 11, 30);
  final hoy = DateTime(2026, 11, 8, 10);

  test('cuenta preguntas por día y franja de 3 horas', () {
    final a = ActividadAlumno.desde(
      fechas: [
        DateTime(2026, 11, 2, 20, 5), // día 0, franja 6 (18–21 h)
        DateTime(2026, 11, 2, 20, 40),
        DateTime(2026, 11, 3, 7), // día 1, franja 2 (6–9 h)
      ],
      inicio: inicio,
      fin: fin,
      hoy: hoy,
    );

    expect(a.dias, 29);
    expect(a.en(0, 6), 2);
    expect(a.en(1, 2), 1);
    expect(a.diasActivos, 2);
    expect(a.franjaFuerte, 6);
    expect(a.indiceHoy, 6);
    expect(a.diasRestantes, 22);
  });

  test('ignora lo que cae fuera de la matrícula', () {
    final a = ActividadAlumno.desde(
      fechas: [DateTime(2026, 10, 30), DateTime(2026, 12, 5)],
      inicio: inicio,
      fin: fin,
      hoy: hoy,
    );
    expect(a.diasActivos, 0);
    expect(a.franjaFuerte, isNull);
  });

  test('la racha no se rompe si hoy todavía no practicó', () {
    final a = ActividadAlumno.desde(
      fechas: [
        DateTime(2026, 11, 5, 9),
        DateTime(2026, 11, 6, 9),
        DateTime(2026, 11, 7, 9),
      ],
      inicio: inicio,
      fin: fin,
      hoy: hoy, // el 8 aún sin actividad
    );
    expect(a.racha, 3);
  });

  test('sin fecha de fin muestra un periodo por defecto', () {
    final a = ActividadAlumno.desde(fechas: const [], inicio: inicio, hoy: hoy);
    expect(a.dias, ActividadAlumno.diasSinFin);
  });

  test('niveles de intensidad del cuadrito', () {
    expect([0, 1, 2, 3, 5, 9].map(ActividadAlumno.nivel), [0, 1, 2, 2, 3, 4]);
  });
}
