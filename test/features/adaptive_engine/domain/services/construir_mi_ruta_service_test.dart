import 'package:academiapp_v2/features/adaptive_engine/domain/entities/recomendacion.dart';
import 'package:academiapp_v2/features/adaptive_engine/domain/services/construir_mi_ruta_service.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/estado_dominio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes_mi_ruta.dart';

void main() {
  test('sin evidencias la ruta queda vacia', () async {
    final service = ConstruirMiRutaService(
      repositorio: RepositorioEvidenciaEnMemoria(const []),
    );

    final ruta = await service.construir(usuarioId: 'u', matriculaId: 'm1');

    expect(ruta, isEmpty);
  });

  test(
    'evidencias -> BKT -> recomendacion, de lo mas urgente a lo menos',
    () async {
      final service = ConstruirMiRutaService(
        repositorio: RepositorioEvidenciaEnMemoria(
          [
            // Secuencia del ejemplo documentado: ❌ ❌ ✅ ✅ ✅ ≈ 91.56 % -> alto.
            ...evidenciasDe('algebra-02__general', [
              false,
              false,
              true,
              true,
              true,
            ]),
            // Dos fallos -> dominio bajo.
            ...evidenciasDe('aritmetica-02__general', [false, false]),
          ],
          const {
            'algebra-02__general': 'algebra-02',
            'aritmetica-02__general': 'aritmetica-02',
          },
        ),
      );

      final ruta = await service.construir(usuarioId: 'u', matriculaId: 'm1');

      expect(ruta.length, 2);

      expect(ruta.first.temaId, 'aritmetica-02');
      expect(ruta.first.estado.nivel, NivelDominio.bajo);
      expect(ruta.first.recomendacion.tipo, TipoRecomendacion.reforzar);
      expect(ruta.first.cantidadEvidencias, 2);

      expect(ruta.last.temaId, 'algebra-02');
      expect(ruta.last.estado.valor, closeTo(0.9156, 0.0005));
      expect(ruta.last.recomendacion.tipo, TipoRecomendacion.profundizar);
    },
  );
}
