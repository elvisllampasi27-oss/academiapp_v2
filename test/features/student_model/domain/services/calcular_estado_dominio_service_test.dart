import 'package:academiapp_v2/features/student_model/domain/entities/estado_dominio.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/evidencia.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/parametros_bkt.dart';
import 'package:academiapp_v2/features/student_model/domain/services/calcular_estado_dominio_service.dart';
import 'package:academiapp_v2/features/student_model/domain/services/modelo_bkt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parametros = ParametrosBkt(
    conocimientoInicial: 0.20,
    aprendizaje: 0.10,
    adivinanza: 0.25,
    desliz: 0.10,
  );

  const service = CalcularEstadoDominioService(modeloBkt: ModeloBktService());

  test('sin evidencias conserva el conocimiento inicial', () {
    final estado = service.calcular(
      matriculaId: 'matricula-1',
      habilidadId: 'suma-matrices',
      evidencias: const [],
      parametros: parametros,
      actualizadoEn: DateTime(2026, 10, 20),
    );

    expect(estado.valor, closeTo(0.20, 0.0001));
    expect(estado.nivel, NivelDominio.bajo);
    expect(estado.modeloVersion, 'bkt-v1');
  });

  test('calcula el dominio procesando evidencias en orden cronologico', () {
    final evidencias = [
      Evidencia(
        id: 'evidencia-1',
        matriculaId: 'matricula-1',
        respuestaId: 'respuesta-1',
        habilidadId: 'suma-matrices',
        origen: OrigenEvidencia.practica,
        resultado: ResultadoEvidencia.incorrecta,
        dificultad: DificultadEvidencia.intermedia,
        numeroIntento: 1,
        ayudaUtilizada: false,
        fecha: DateTime(2026, 10, 20, 8),
      ),
      Evidencia(
        id: 'evidencia-2',
        matriculaId: 'matricula-1',
        respuestaId: 'respuesta-2',
        habilidadId: 'suma-matrices',
        origen: OrigenEvidencia.practica,
        resultado: ResultadoEvidencia.incorrecta,
        dificultad: DificultadEvidencia.intermedia,
        numeroIntento: 1,
        ayudaUtilizada: false,
        fecha: DateTime(2026, 10, 20, 9),
      ),
      Evidencia(
        id: 'evidencia-3',
        matriculaId: 'matricula-1',
        respuestaId: 'respuesta-3',
        habilidadId: 'suma-matrices',
        origen: OrigenEvidencia.practica,
        resultado: ResultadoEvidencia.correcta,
        dificultad: DificultadEvidencia.intermedia,
        numeroIntento: 1,
        ayudaUtilizada: false,
        fecha: DateTime(2026, 10, 20, 10),
      ),
      Evidencia(
        id: 'evidencia-4',
        matriculaId: 'matricula-1',
        respuestaId: 'respuesta-4',
        habilidadId: 'suma-matrices',
        origen: OrigenEvidencia.practica,
        resultado: ResultadoEvidencia.correcta,
        dificultad: DificultadEvidencia.intermedia,
        numeroIntento: 1,
        ayudaUtilizada: false,
        fecha: DateTime(2026, 10, 20, 11),
      ),
      Evidencia(
        id: 'evidencia-5',
        matriculaId: 'matricula-1',
        respuestaId: 'respuesta-5',
        habilidadId: 'suma-matrices',
        origen: OrigenEvidencia.practica,
        resultado: ResultadoEvidencia.correcta,
        dificultad: DificultadEvidencia.intermedia,
        numeroIntento: 1,
        ayudaUtilizada: false,
        fecha: DateTime(2026, 10, 20, 12),
      ),
    ];

    final estado = service.calcular(
      matriculaId: 'matricula-1',
      habilidadId: 'suma-matrices',
      evidencias: evidencias,
      parametros: parametros,
      actualizadoEn: DateTime(2026, 10, 20, 12),
    );

    expect(estado.valor, greaterThan(parametros.conocimientoInicial));
    expect(estado.matriculaId, 'matricula-1');
    expect(estado.habilidadId, 'suma-matrices');
  });
}
