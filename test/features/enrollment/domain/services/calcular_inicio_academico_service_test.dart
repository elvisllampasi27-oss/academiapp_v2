import 'package:academiapp_v2/features/enrollment/domain/entities/configuracion_inicio.dart';
import 'package:academiapp_v2/features/enrollment/domain/services/calcular_inicio_academico_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = CalcularInicioAcademicoService();

  const configuracion = ConfiguracionInicio(horaInicio: 7, horaCorte: 18);

  test('matricula antes del corte inicia el mismo dia academico', () {
    final resultado = service.calcular(
      fechaMatricula: DateTime(2026, 10, 19, 10),
      fechaAperturaVersion: DateTime(2026, 10, 1),
      configuracion: configuracion,
    );

    expect(resultado, DateTime(2026, 10, 19, 7));
  });

  test('matricula despues del corte inicia al dia siguiente', () {
    final resultado = service.calcular(
      fechaMatricula: DateTime(2026, 10, 19, 22),
      fechaAperturaVersion: DateTime(2026, 10, 1),
      configuracion: configuracion,
    );

    expect(resultado, DateTime(2026, 10, 20, 7));
  });

  test('matricula tarde el sabado omite el domingo', () {
    final resultado = service.calcular(
      fechaMatricula: DateTime(2026, 10, 24, 23),
      fechaAperturaVersion: DateTime(2026, 10, 1),
      configuracion: configuracion,
    );

    expect(resultado, DateTime(2026, 10, 26, 7));
  });

  test('matricula en domingo inicia el lunes', () {
    final resultado = service.calcular(
      fechaMatricula: DateTime(2026, 10, 25, 10),
      fechaAperturaVersion: DateTime(2026, 10, 1),
      configuracion: configuracion,
    );

    expect(resultado, DateTime(2026, 10, 26, 7));
  });

  test('espera si la version academica aun no esta abierta', () {
    final resultado = service.calcular(
      fechaMatricula: DateTime(2026, 10, 20, 10),
      fechaAperturaVersion: DateTime(2026, 10, 26),
      configuracion: configuracion,
    );

    expect(resultado, DateTime(2026, 10, 26, 7));
  });
}
