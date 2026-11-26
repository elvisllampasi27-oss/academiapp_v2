import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/services/servicio_preparacion_cuenta.dart';

class FirebaseServicioPreparacionCuenta implements ServicioPreparacionCuenta {
  final FirebaseFunctions functions;

  FirebaseServicioPreparacionCuenta({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<PlanPreparado> preparar() async {
    try {
      final r = await functions
          .httpsCallable('prepararCuenta')
          .call<Map<Object?, Object?>>();
      return planDesdeMapa(r.data);
    } on FirebaseFunctionsException catch (e) {
      throw ExcepcionPreparacionCuenta(
        mensajeErrorPreparacion(e.code, e.message),
      );
    }
  }
}

/// Lo que responde prepararCuenta: { nueva, versionNombre, inicioMs,
/// pruebaHastaMs }.
PlanPreparado planDesdeMapa(Map<Object?, Object?> datos) {
  DateTime? fecha(Object? ms) =>
      ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null;
  return PlanPreparado(
    nuevo: datos['nueva'] == true,
    versionNombre: datos['versionNombre'] as String?,
    inicio: fecha(datos['inicioMs']),
    pruebaHasta: fecha(datos['pruebaHastaMs']),
  );
}
