import 'dart:convert';

/// Importar preguntas desde JSON (mismo formato que la V1 y los scripts de
/// tool/). Dart puro: se prueba sin Flutter ni Firebase.

/// Dónde viven las figuras subidas con `firebase deploy --only hosting`.
const urlHosting = 'https://academiapp-v2-7b9ce.web.app';

class PreguntaImportada {
  /// Posición en el JSON (desde 1).
  final int numero;
  final String enunciado;
  final List<String> opciones;
  final int correcta;
  final String? solucion;
  final String? imagen;
  final String? imagenSolucion;
  final String? seccion;

  const PreguntaImportada({
    required this.numero,
    required this.enunciado,
    required this.opciones,
    required this.correcta,
    this.solucion,
    this.imagen,
    this.imagenSolucion,
    this.seccion,
  });

  bool get tieneLatex =>
      [enunciado, ...opciones, solucion ?? ''].any((t) => t.contains(r'$'));

  bool get tieneImagen => imagen != null || imagenSolucion != null;

  /// Copia con las imágenes ya subidas: [subidas] va de la dirección
  /// provisional (por nombre de archivo) a la dirección real.
  PreguntaImportada conImagenes(Map<String, String> subidas) =>
      PreguntaImportada(
        numero: numero,
        enunciado: enunciado,
        opciones: opciones,
        correcta: correcta,
        solucion: solucion,
        imagen: subidas[imagen] ?? imagen,
        imagenSolucion: subidas[imagenSolucion] ?? imagenSolucion,
        seccion: seccion,
      );

  /// Archivos de imagen que hay que subir (no los enlaces https que ya
  /// venían en el JSON).
  List<String> archivosEn(String carpetaUrl) => [
    for (final url in [imagen, imagenSolucion])
      if (url != null && url.startsWith(carpetaUrl))
        Uri.decodeComponent(url.substring(carpetaUrl.length)),
  ];
}

class AvisoImportacion {
  final int? numero;
  final String texto;

  const AvisoImportacion(this.texto, {this.numero});

  @override
  String toString() => numero == null ? texto : 'Pregunta $numero: $texto';
}

class SeccionImportada {
  final String nombre;
  final int desde;
  final int hasta;

  const SeccionImportada(this.nombre, this.desde, this.hasta);
}

class ResultadoImportacion {
  final List<PreguntaImportada> preguntas;
  final List<AvisoImportacion> avisos;
  final List<SeccionImportada> secciones;

  const ResultadoImportacion({
    required this.preguntas,
    required this.avisos,
    this.secciones = const [],
  });

  ResultadoImportacion conImagenes(Map<String, String> subidas) =>
      ResultadoImportacion(
        preguntas: [for (final p in preguntas) p.conImagenes(subidas)],
        avisos: avisos,
        secciones: secciones,
      );

  int get conLatex => preguntas.where((p) => p.tieneLatex).length;
  int get conImagen => preguntas.where((p) => p.tieneImagen).length;

  /// Sección de una pregunta: la suya, la del rango por número o "General".
  String seccionDe(PreguntaImportada p) =>
      p.seccion ??
      secciones
          .where((s) => p.numero >= s.desde && p.numero <= s.hasta)
          .firstOrNull
          ?.nombre ??
      'General';
}

const _letras = 'abcdefgh';

/// Lee el JSON pegado o abierto. Acepta:
///   [ {...}, ... ]                         (lista de preguntas)
///   { "preguntas": [...], "secciones": [...] }
///   { "evaluaciones": [ { "preguntas": [...] } ] }   (formato de tool/)
/// Cada pregunta: enunciado | pregunta | latex, opciones, y la correcta como
/// índice ("correcta": 1), letra ("correcta": "b") o texto ("clave": "30").
/// Opcionales: explicacion | solucion | latexSolucion, imagen,
/// imagenSolucion, seccion. Una imagen que no es un enlace https se toma
/// como nombre de archivo y se busca con [urlDeArchivo].
ResultadoImportacion leerPreguntasJson(
  String texto, {
  required String Function(String archivo) urlDeArchivo,
}) {
  final Object? datos;
  try {
    datos = jsonDecode(texto);
  } on FormatException catch (e) {
    throw FormatException('El texto no es JSON válido (${e.message}).');
  }

  final lista = switch (datos) {
    List l => l,
    {'preguntas': List l} => l,
    {'evaluaciones': [{'preguntas': List l}, ...]} => l,
    _ => throw const FormatException(
      'No encontré la lista de preguntas ("preguntas": [...]).',
    ),
  };

  final secciones = <SeccionImportada>[
    if (datos case {'secciones': List s})
      for (final x in s)
        if (x case {'nombre': String n, 'desde': int d, 'hasta': int h})
          SeccionImportada(n, d, h),
  ];

  String texto0(Object? v) => v == null ? '' : '$v'.trim();
  String? opcional(Object? v) => texto0(v).isEmpty ? null : texto0(v);

  final preguntas = <PreguntaImportada>[];
  final avisos = <AvisoImportacion>[];

  for (final (i, bruta) in lista.indexed) {
    final numero = i + 1;
    if (bruta is! Map) {
      avisos.add(
        AvisoImportacion('no es un objeto, se omite.', numero: numero),
      );
      continue;
    }
    final enunciado = [
      bruta['enunciado'],
      bruta['pregunta'],
      bruta['latex'],
    ].map(texto0).firstWhere((t) => t.isNotEmpty, orElse: () => '');
    final opciones = [
      for (final o in (bruta['opciones'] as List?) ?? const [])
        texto0(o is Map ? o['texto'] : o),
    ];

    if (enunciado.isEmpty) {
      avisos.add(AvisoImportacion('sin enunciado, se omite.', numero: numero));
      continue;
    }
    if (opciones.length < 2 ||
        opciones.length > _letras.length ||
        opciones.any((o) => o.isEmpty)) {
      avisos.add(
        AvisoImportacion('alternativas incompletas, se omite.', numero: numero),
      );
      continue;
    }

    final correcta = _indiceCorrecta(bruta, opciones);
    if (correcta == null) {
      avisos.add(
        AvisoImportacion(
          'no se sabe cuál es la correcta (usa "correcta": 0, "correcta": '
          '"a" o "clave": "texto de la alternativa"), se omite.',
          numero: numero,
        ),
      );
      continue;
    }

    String? imagen(Object? v) {
      final t = texto0(v);
      if (t.isEmpty) return null;
      if (t.startsWith('https://')) return t;
      if (t.startsWith('http://')) {
        avisos.add(
          AvisoImportacion(
            'la imagen debe ser https; se ignora.',
            numero: numero,
          ),
        );
        return null;
      }
      return urlDeArchivo(t);
    }

    preguntas.add(
      PreguntaImportada(
        numero: numero,
        enunciado: enunciado,
        opciones: opciones,
        correcta: correcta,
        solucion:
            opcional(bruta['explicacion']) ??
            opcional(bruta['solucion']) ??
            opcional(bruta['latexSolucion']),
        imagen: imagen(bruta['imagen']),
        imagenSolucion: imagen(bruta['imagenSolucion']),
        seccion: opcional(bruta['seccion']),
      ),
    );
  }

  if (lista.isEmpty) {
    avisos.add(const AvisoImportacion('La lista de preguntas está vacía.'));
  }
  return ResultadoImportacion(
    preguntas: preguntas,
    avisos: avisos,
    secciones: secciones,
  );
}

int? _indiceCorrecta(Map bruta, List<String> opciones) {
  int? valido(int i) => i >= 0 && i < opciones.length ? i : null;
  int? deTexto(String t) {
    final limpio = t.trim();
    if (limpio.length == 1 && _letras.contains(limpio.toLowerCase())) {
      return valido(_letras.indexOf(limpio.toLowerCase()));
    }
    final i = opciones.indexOf(limpio);
    return i >= 0 ? i : null;
  }

  for (final clave in ['correcta', 'respuestaCorrecta', 'clave', 'respuesta']) {
    final v = bruta[clave];
    if (v is int) return valido(v);
    if (v is String && v.trim().isNotEmpty) return deTexto(v);
  }
  return null;
}

/// "16-11-2025" -> "2025-11-16" (o null).
String? fechaIsoDeCarpeta(String carpeta) {
  final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(carpeta.trim());
  return m == null ? null : '${m[3]}-${m[2]}-${m[1]}';
}

/// "Exonerados · 16 nov 2025".
String tituloExamen(String tipo, String fechaIso) {
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final [a, m, d] = fechaIso.split('-').map(int.parse).toList();
  final nombre = tipo == 'ordinario' ? 'Ordinario' : 'Exonerados';
  return '$nombre · $d ${meses[m - 1]} $a';
}
