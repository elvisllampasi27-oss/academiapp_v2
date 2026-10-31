import 'pregunta.dart';

/// Opción tal como la ve el estudiante: SIN saber si es la correcta.
class OpcionPresentada {
  final String id;
  final String texto;

  const OpcionPresentada({required this.id, required this.texto});
}

/// Pregunta tal como llega al celular. La respuesta correcta y la
/// explicación viven en el servidor y solo vuelven después de corregir.
class PreguntaPresentada {
  final String id;
  final String evaluacionId;
  final String enunciado;
  final DificultadPregunta dificultad;
  final int orden;
  final List<OpcionPresentada> opciones;

  const PreguntaPresentada({
    required this.id,
    required this.evaluacionId,
    required this.enunciado,
    required this.dificultad,
    required this.orden,
    required this.opciones,
  });
}
