/// Modelos del panel: a diferencia de la app del estudiante, aquí la
/// pregunta incluye la respuesta correcta y la solución.
class ExamenAdmin {
  final String id;
  final String titulo;
  final String tipo;
  final String fecha;
  final String estado;
  final int totalPreguntas;

  const ExamenAdmin({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.fecha,
    required this.estado,
    required this.totalPreguntas,
  });

  bool get publicado => estado == 'publicado';
}

class PreguntaAdmin {
  static const letras = 'abcdefgh';

  final String id;
  final String examenId;
  final int numero;
  final String seccion;
  final String enunciado;
  final List<String> opciones;

  /// Índice de la opción correcta.
  final int correcta;
  final String? solucion;
  final String? imagen;
  final String? imagenSolucion;
  final bool activa;

  const PreguntaAdmin({
    required this.id,
    required this.examenId,
    required this.numero,
    required this.seccion,
    required this.enunciado,
    required this.opciones,
    required this.correcta,
    this.solucion,
    this.imagen,
    this.imagenSolucion,
    this.activa = true,
  });

  /// Id de una pregunta nueva: `{examen}__p{numero con 3 cifras}`.
  static String idPara(String examenId, int numero) =>
      '${examenId}__p${numero.toString().padLeft(3, '0')}';

  bool get tieneSolucion =>
      (solucion?.trim().isNotEmpty ?? false) || imagenSolucion != null;

  /// Mensaje de error para el administrador, o null si se puede guardar.
  String? validar() {
    if (enunciado.trim().isEmpty) return 'Falta el enunciado.';
    if (seccion.trim().isEmpty) return 'Falta la sección.';
    if (opciones.length < 2 || opciones.length > letras.length) {
      return 'Debe tener entre 2 y ${letras.length} alternativas.';
    }
    if (opciones.any((o) => o.trim().isEmpty)) {
      return 'Hay alternativas vacías.';
    }
    if (correcta < 0 || correcta >= opciones.length) {
      return 'Marca cuál es la alternativa correcta.';
    }
    for (final url in [imagen, imagenSolucion]) {
      if (url != null && !(Uri.tryParse(url)?.isScheme('https') ?? false)) {
        return 'Las imágenes deben ser enlaces https.';
      }
    }
    return null;
  }

  /// Documento público (preguntas_examen): sin la respuesta.
  Map<String, Object?> datosPregunta() => {
    'examenId': examenId,
    'numero': numero,
    'seccion': seccion.trim(),
    'enunciado': enunciado.trim(),
    'opciones': [
      for (final (i, texto) in opciones.indexed)
        {'id': letras[i], 'texto': texto.trim()},
    ],
    'imagen': imagen,
    'activa': activa,
  };

  /// Documento privado (claves_examen): solo lo lee el servidor y el admin.
  Map<String, Object?> datosClave() => {
    'examenId': examenId,
    'opcionCorrectaId': letras[correcta],
    'solucion': (solucion?.trim().isEmpty ?? true) ? null : solucion!.trim(),
    'imagenSolucion': imagenSolucion,
  };

  PreguntaAdmin copiar({
    String? seccion,
    String? enunciado,
    List<String>? opciones,
    int? correcta,
    String? solucion,
    String? imagen,
    String? imagenSolucion,
    bool? activa,
    bool sinImagen = false,
    bool sinImagenSolucion = false,
  }) {
    return PreguntaAdmin(
      id: id,
      examenId: examenId,
      numero: numero,
      seccion: seccion ?? this.seccion,
      enunciado: enunciado ?? this.enunciado,
      opciones: opciones ?? this.opciones,
      correcta: correcta ?? this.correcta,
      solucion: solucion ?? this.solucion,
      imagen: sinImagen ? null : (imagen ?? this.imagen),
      imagenSolucion: sinImagenSolucion
          ? null
          : (imagenSolucion ?? this.imagenSolucion),
      activa: activa ?? this.activa,
    );
  }
}

/// Lee una pregunta desde sus dos documentos (pregunta + clave).
PreguntaAdmin preguntaAdminDesdeMapas(
  String id,
  Map<String, dynamic> pregunta,
  Map<String, dynamic>? clave,
) {
  final opciones = [
    for (final o in (pregunta['opciones'] as List? ?? const []))
      if (o is Map) o,
  ];
  final correctaId = clave?['opcionCorrectaId'];

  String? texto(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

  return PreguntaAdmin(
    id: id,
    examenId: pregunta['examenId'] as String? ?? '',
    numero: (pregunta['numero'] as num?)?.toInt() ?? 0,
    seccion: pregunta['seccion'] as String? ?? '',
    enunciado: pregunta['enunciado'] as String? ?? '',
    opciones: [for (final o in opciones) '${o['texto'] ?? ''}'],
    correcta: opciones.indexWhere((o) => o['id'] == correctaId),
    solucion: texto(clave?['solucion']),
    imagen: texto(pregunta['imagen']),
    imagenSolucion: texto(clave?['imagenSolucion']),
    activa: pregunta['activa'] != false,
  );
}

/// Totales por sección de las preguntas activas (para el documento del examen).
List<Map<String, Object>> seccionesDe(Iterable<PreguntaAdmin> preguntas) {
  final totales = <String, int>{};
  for (final p in preguntas) {
    if (p.activa) totales[p.seccion] = (totales[p.seccion] ?? 0) + 1;
  }
  return [
    for (final e in totales.entries) {'nombre': e.key, 'total': e.value},
  ];
}
