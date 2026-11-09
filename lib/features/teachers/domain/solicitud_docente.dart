enum EstadoSolicitudDocente {
  pendiente('En revisión'),
  aprobada('Aprobada'),
  rechazada('No aprobada');

  final String etiqueta;

  const EstadoSolicitudDocente(this.etiqueta);

  static EstadoSolicitudDocente? desde(Object? valor) =>
      values.where((e) => e.name == valor).firstOrNull;
}

/// Pedido de un docente para compartir sus clases. Se guarda una por
/// persona (solicitudes_docente/{uid}); al aprobarla, el panel crea
/// docentes/{uid}.
class SolicitudDocente {
  final String uid;
  final String nombre;
  final String correo;

  /// Celular (WhatsApp) para verificar que es docente. Solo lo ven él y el
  /// administrador.
  final String celular;

  /// Lo que enseña, escrito por el docente ("Historia del Perú").
  final String cursos;

  /// Canal de YouTube o redes donde se ve su trabajo.
  final List<String> enlaces;
  final String mensaje;
  final EstadoSolicitudDocente estado;
  final DateTime creadaEn;

  /// Por qué no se aprobó (o se retiró la cuenta).
  final String? motivo;

  const SolicitudDocente({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.celular,
    required this.cursos,
    required this.enlaces,
    required this.mensaje,
    required this.estado,
    required this.creadaEn,
    this.motivo,
  });
}

/// Lo público de un docente aprobado (docentes/{uid}): su página.
class PerfilDocente {
  final String uid;
  final String nombre;
  final String cursos;
  final List<String> enlaces;

  const PerfilDocente({
    required this.uid,
    required this.nombre,
    required this.cursos,
    required this.enlaces,
  });
}

abstract class RepositorioDocentes {
  Future<SolicitudDocente?> miSolicitud(String uid);

  /// null si no es (o ya no es) docente.
  Future<PerfilDocente?> perfil(String uid);

  /// Envía (o vuelve a enviar, si no se aprobó) la solicitud.
  Future<void> solicitar({
    required String uid,
    required String nombre,
    required String correo,
    required String celular,
    required String cursos,
    required List<String> enlaces,
    required String mensaje,
  });
}

/// Límites (los mismos que en firestore.rules).
const minMensajeDocente = 20;
const maxMensajeDocente = 1000;
const maxCursosDocente = 200;
const maxEnlacesDocente = 3;

/// El celular sin espacios ni guiones ("987 654 321" → "987654321").
String celularLimpio(String escrito) =>
    escrito.replaceAll(RegExp(r'[\s-]'), '').replaceFirst(RegExp(r'^\+51'), '');

/// Los enlaces escritos, sin vacíos ni repetidos.
List<String> enlacesLimpios(Iterable<String> escritos) => {
  for (final e in escritos)
    if (e.trim().isNotEmpty) e.trim(),
}.toList();

/// Qué falta para enviar la solicitud (null si está completa).
String? errorSolicitudDocente({
  required String celular,
  required String cursos,
  required List<String> enlaces,
  required String mensaje,
}) {
  if (!RegExp(r'^9\d{8}$').hasMatch(celularLimpio(celular))) {
    return 'Escribe tu celular (9 dígitos, empieza con 9).';
  }
  final c = cursos.trim();
  if (c.length < 3) return 'Escribe el curso o los cursos que enseñas.';
  if (c.length > maxCursosDocente) return 'Los cursos son demasiado largos.';
  if (enlaces.isEmpty) {
    return 'Agrega tu canal de YouTube o una red social donde enseñes.';
  }
  if (enlaces.length > maxEnlacesDocente) {
    return 'Agrega como máximo $maxEnlacesDocente enlaces.';
  }
  for (final e in enlaces) {
    final uri = Uri.tryParse(e);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return 'Los enlaces deben empezar con https:// ($e).';
    }
  }
  final m = mensaje.trim();
  if (m.length < minMensajeDocente) {
    return 'Cuéntanos un poco más de ti (al menos $minMensajeDocente '
        'letras).';
  }
  if (m.length > maxMensajeDocente) return 'El mensaje es demasiado largo.';
  return null;
}
