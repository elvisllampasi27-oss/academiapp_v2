enum TipoExamen { ordinario, exonerados }

class SeccionExamen {
  final String nombre;
  final int total;

  const SeccionExamen({required this.nombre, required this.total});
}

/// Examen pasado de admisión de la UNSCH (Ordinario o Exonerados).
class ExamenPasado {
  final String id;
  final TipoExamen tipo;
  final DateTime fecha;
  final String titulo;
  final int totalPreguntas;
  final List<SeccionExamen> secciones;

  const ExamenPasado({
    required this.id,
    required this.tipo,
    required this.fecha,
    required this.titulo,
    required this.totalPreguntas,
    this.secciones = const [],
  });
}

class OpcionExamen {
  final String id;
  final String texto;

  const OpcionExamen({required this.id, required this.texto});
}

/// Pregunta tal como llega al celular: sin la respuesta correcta.
class PreguntaExamen {
  final String id;
  final int numero;
  final String seccion;
  final String enunciado;
  final List<OpcionExamen> opciones;
  final String? imagen;

  const PreguntaExamen({
    required this.id,
    required this.numero,
    required this.seccion,
    required this.enunciado,
    required this.opciones,
    this.imagen,
  });

  /// "A", "B"... de una opción, según su posición.
  String letraDe(String opcionId) {
    final i = opciones.indexWhere((o) => o.id == opcionId);
    return i < 0 ? '?' : String.fromCharCode(65 + i);
  }
}

/// Respuesta del servidor tras responder una pregunta de un examen pasado.
class RevisionPregunta {
  final bool esCorrecta;
  final String opcionCorrectaId;
  final String? solucion;
  final String? imagenSolucion;

  const RevisionPregunta({
    required this.esCorrecta,
    required this.opcionCorrectaId,
    this.solucion,
    this.imagenSolucion,
  });
}
