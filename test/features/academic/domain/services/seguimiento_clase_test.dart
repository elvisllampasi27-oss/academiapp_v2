import 'package:academiapp_v2/features/academic/domain/entities/progreso_clase.dart';
import 'package:academiapp_v2/features/academic/domain/services/seguimiento_clase.dart';
import 'package:academiapp_v2/features/academic/infrastructure/repositories/repositorio_progreso_clase_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Simula ver de corrido desde [desde] hasta [hasta], medio segundo a la vez.
  void ver(SeguimientoClase s, double desde, double hasta) {
    for (var t = desde; t <= hasta; t += 0.5) {
      s.registrar(posicion: t, duracion: 100);
    }
  }

  test('viendo de corrido avanza y se completa al 90 %', () {
    final s = SeguimientoClase();

    ver(s, 0, 50);
    expect(s.fraccion, closeTo(0.5, 0.01));
    expect(s.completada, isFalse);

    ver(s, 50, 90);
    expect(s.completada, isTrue);
    expect(s.fraccion, 1);
  });

  test('adelantar no suma, pero lo que se ve despues del salto si', () {
    final s = SeguimientoClase();

    ver(s, 0, 10);
    ver(s, 80, 100);

    expect(s.visto, closeTo(30, 0.01));
    expect(s.completada, isFalse);
    // Ofrece volver a la parte que se saltó.
    expect(s.saltadoDesde, closeTo(10, 0.01));
    expect(s.continuarDesde, closeTo(10, 0.01));
  });

  test('al ver la parte saltada se completa y deja de avisar', () {
    final s = SeguimientoClase();

    ver(s, 0, 10);
    ver(s, 80, 100);
    ver(s, 10, 75);

    expect(s.completada, isTrue);
    expect(s.saltadoDesde, isNull);
  });

  test('repetir una parte no la cuenta dos veces', () {
    final s = SeguimientoClase();

    ver(s, 0, 40);
    ver(s, 5, 40);

    expect(s.visto, closeTo(40, 0.01));
    expect(s.tramos, hasLength(1));
  });

  test('viendo al final de lo visto no avisa de saltos', () {
    final s = SeguimientoClase();

    ver(s, 0, 30);

    expect(s.saltadoDesde, isNull);
  });

  test('continua desde el progreso guardado', () {
    final s = SeguimientoClase.desde(
      const ProgresoClase(
        temaId: 't',
        versionId: 'v',
        tramos: [(0, 60)],
        duracion: 100,
        completada: false,
      ),
    );

    expect(s.fraccion, closeTo(0.6, 0.01));
    expect(s.continuarDesde, 60);
    ver(s, 60, 92);
    expect(s.completada, isTrue);

    final progreso = s.aProgreso(temaId: 't', versionId: 'v');
    expect(progreso.completada, isTrue);
    expect(progreso.duracion, 100);
  });

  test('los tramos se leen de la lista plana de Firestore', () {
    expect(tramosDesdeLista([0, 10.5, 30, 40]), [(0.0, 10.5), (30.0, 40.0)]);
    expect(tramosDesdeLista(null), isEmpty);
  });
}
