import 'package:academiapp_v2/features/adaptive_engine/domain/entities/recomendacion.dart';
import 'package:academiapp_v2/features/adaptive_engine/domain/services/adaptive_engine_service.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/estado_dominio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = AdaptiveEngineService();

  EstadoDominio crearEstado({
    required double valor,
    required NivelDominio nivel,
    String habilidadId = 'suma-matrices',
  }) {
    return EstadoDominio(
      matriculaId: 'matricula-1',
      habilidadId: habilidadId,
      valor: valor,
      nivel: nivel,
      modeloVersion: 'bkt-v1',
      actualizadoEn: DateTime(2026, 10, 20),
    );
  }

  test('recomienda reforzar cuando el dominio es bajo', () {
    final recomendacion = service.generarRecomendacion(
      estadoDominio: crearEstado(valor: 0.32, nivel: NivelDominio.bajo),
      fecha: DateTime(2026, 10, 20),
    );

    expect(recomendacion.tipo, TipoRecomendacion.reforzar);
    expect(recomendacion.prioridad, 3);
  });

  test('recomienda practicar cuando el dominio es medio', () {
    final recomendacion = service.generarRecomendacion(
      estadoDominio: crearEstado(valor: 0.65, nivel: NivelDominio.medio),
      fecha: DateTime(2026, 10, 20),
    );

    expect(recomendacion.tipo, TipoRecomendacion.practicar);
    expect(recomendacion.prioridad, 2);
  });

  test('recomienda profundizar cuando el dominio es alto', () {
    final recomendacion = service.generarRecomendacion(
      estadoDominio: crearEstado(valor: 0.91, nivel: NivelDominio.alto),
      fecha: DateTime(2026, 10, 20),
    );

    expect(recomendacion.tipo, TipoRecomendacion.profundizar);
    expect(recomendacion.prioridad, 1);
  });

  test('construye Mi Ruta ordenando recomendaciones por prioridad', () {
    final estados = [
      crearEstado(valor: 0.91, nivel: NivelDominio.alto),
      crearEstado(valor: 0.32, nivel: NivelDominio.bajo),
      crearEstado(valor: 0.65, nivel: NivelDominio.medio),
    ];

    final ruta = service.construirMiRuta(
      estadosDominio: estados,
      fecha: DateTime(2026, 10, 20),
    );

    expect(ruta.length, 3);

    expect(ruta[0].tipo, TipoRecomendacion.reforzar);
    expect(ruta[0].prioridad, 3);

    expect(ruta[1].tipo, TipoRecomendacion.practicar);
    expect(ruta[1].prioridad, 2);

    expect(ruta[2].tipo, TipoRecomendacion.profundizar);
    expect(ruta[2].prioridad, 1);
  });

  test('Mi Ruta conserva la habilidad asociada a cada recomendacion', () {
    final estados = [
      crearEstado(
        habilidadId: 'potencias',
        valor: 0.91,
        nivel: NivelDominio.alto,
      ),
      crearEstado(
        habilidadId: 'suma-matrices',
        valor: 0.32,
        nivel: NivelDominio.bajo,
      ),
      crearEstado(
        habilidadId: 'factorizacion',
        valor: 0.65,
        nivel: NivelDominio.medio,
      ),
    ];

    final ruta = service.construirMiRuta(
      estadosDominio: estados,
      fecha: DateTime(2026, 10, 20),
    );

    expect(ruta[0].habilidadId, 'suma-matrices');
    expect(ruta[0].tipo, TipoRecomendacion.reforzar);

    expect(ruta[1].habilidadId, 'factorizacion');
    expect(ruta[1].tipo, TipoRecomendacion.practicar);

    expect(ruta[2].habilidadId, 'potencias');
    expect(ruta[2].tipo, TipoRecomendacion.profundizar);
  });
}
