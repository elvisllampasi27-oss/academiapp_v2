/// Tipos sugeridos en el panel. Con [tipoOtro] el administrador escribe
/// el suyo (por ejemplo "Crónica" o "Fábula").
const tiposNarracion = [
  'Cuento',
  'Novela',
  'Leyenda',
  'Mito',
  'Guerra o batalla',
  'Biografía',
  'Historia',
];

const tipoOtro = 'Otro';

/// Audio que acompaña a un tema (un cuento, una batalla, una biografía…).
/// Va debajo de la clase, sobre todo en los cursos de letras.
class Narracion {
  final String id;
  final String versionId;
  final String temaId;
  final String titulo;

  /// Uno de [tiposNarracion] o el que escribió el administrador.
  final String tipo;
  final String? descripcion;

  /// Enlace para reproducir (descarga de Storage o, en pruebas, uno
  /// pegado).
  final String url;

  /// Ruta en Storage; null si es un enlace pegado (no hay archivo que
  /// borrar).
  final String? rutaAudio;
  final DateTime? creada;

  const Narracion({
    required this.id,
    required this.versionId,
    required this.temaId,
    required this.titulo,
    required this.tipo,
    required this.url,
    this.descripcion,
    this.rutaAudio,
    this.creada,
  });
}

/// En el orden en que se subieron (las que no tienen fecha, al final).
List<Narracion> ordenarNarraciones(Iterable<Narracion> narraciones) =>
    narraciones.toList()..sort((a, b) {
      final (fa, fb) = (a.creada, b.creada);
      if (fa == null) return fb == null ? 0 : 1;
      if (fb == null) return -1;
      return fa.compareTo(fb);
    });

abstract class RepositorioNarraciones {
  Future<List<Narracion>> delTema({
    required String versionId,
    required String temaId,
  });
}
