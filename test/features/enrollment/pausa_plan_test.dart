import 'package:academiapp_v2/features/enrollment/domain/pausa_plan.dart';
import 'package:flutter_test/flutter_test.dart';

// Los mismos casos que functions/test/pausa.test.js. El plan empezó el
// lunes 2 de noviembre de 2026.
final inicio = DateTime(2026, 11, 2);
final finPrueba = DateTime(2026, 11, 9);

void main() {
  test(
    'semana del plan: de lunes a domingo; sábado o domingo, la siguiente',
    () {
      expect(semanaDelPlan(inicio, DateTime(2026, 11, 2)), 1);
      expect(semanaDelPlan(inicio, DateTime(2026, 11, 8)), 1);
      expect(semanaDelPlan(inicio, DateTime(2026, 11, 9)), 2);
      expect(semanaDelPlan(inicio, DateTime(2026, 11, 1)), 0);
      // Empezó un sábado: su semana 1 es la del lunes 9.
      expect(semanaDelPlan(DateTime(2026, 11, 7), DateTime(2026, 11, 8)), 0);
      expect(semanaDelPlan(DateTime(2026, 11, 7), DateTime(2026, 11, 9)), 1);
    },
  );

  test('pausa: solo si se acabó la prueba o el Premium', () {
    final ahora = DateTime(2026, 12, 1, 10);
    expect(
      pausaDelPlan(
        inicio: inicio,
        premiumHasta: DateTime(2026, 12, 20),
        ahora: ahora,
      ),
      isNull,
    );
    expect(
      pausaDelPlan(inicio: inicio, premiumHasta: null, ahora: ahora),
      isNull,
    );
    final p = pausaDelPlan(
      inicio: inicio,
      premiumHasta: finPrueba,
      pruebaHasta: finPrueba,
      ahora: ahora,
    )!;
    expect((p.semana, p.eraPrueba, p.desde), (2, true, finPrueba));
    final pagado = pausaDelPlan(
      inicio: inicio,
      premiumHasta: DateTime(2026, 11, 26, 15, 30),
      pruebaHasta: finPrueba,
      ahora: ahora,
    )!;
    expect((pagado.semana, pagado.eraPrueba), (4, false));
  });

  test('paga el lunes en que acabó la prueba: sigue igual', () {
    expect(
      retomaDelPlan(
        inicio: inicio,
        premiumHasta: finPrueba,
        ahora: DateTime(2026, 11, 9, 18),
      ),
      isNull,
    );
  });

  test('paga días después: retoma el lunes que viene en su semana', () {
    final r = retomaDelPlan(
      inicio: inicio,
      premiumHasta: finPrueba,
      ahora: DateTime(2026, 11, 18, 20),
    )!;
    expect((r.semana, r.desplazamientoDias), (2, 14));
    expect(r.retomaEl, DateTime(2026, 11, 23));
    final nuevo = inicioRetomado(inicio, r);
    expect(nuevo, DateTime(2026, 11, 16));
    expect(semanaDelPlan(nuevo, r.retomaEl), 2);
  });

  test('si paga un lunes, retoma ese mismo día', () {
    final r = retomaDelPlan(
      inicio: inicio,
      premiumHasta: finPrueba,
      ahora: DateTime(2026, 11, 30, 9),
    )!;
    expect((r.retomaEl, r.desplazamientoDias), (DateTime(2026, 11, 30), 21));
  });

  test('Premium que acabó a mitad de semana: desde el lunes de esa semana', () {
    final r = retomaDelPlan(
      inicio: inicio,
      premiumHasta: DateTime(2026, 12, 3, 15, 30),
      ahora: DateTime(2026, 12, 5, 11),
    )!;
    expect((r.semana, r.desplazamientoDias), (5, 7));
    expect(r.retomaEl, DateTime(2026, 12, 7));
  });
}
