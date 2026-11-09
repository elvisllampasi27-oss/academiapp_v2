import '../../../core/presentation/video/id_youtube.dart';

enum EstadoClaseDocente {
  pendiente('En revisión'),
  aprobada('Publicada'),
  rechazada('No publicada');

  final String etiqueta;

  const EstadoClaseDocente(this.etiqueta);

  static EstadoClaseDocente? desde(Object? valor) =>
      values.where((e) => e.name == valor).firstOrNull;
}

/// Clase que comparte un docente aprobado (un video de YouTube, puede ser
/// "no listado") para un tema. Los alumnos la ven cuando el administrador
/// la publica. El tema es el mismo en todas las versiones.
class ClaseDocente {
  final String id;
  final String docenteUid;
  final String docenteNombre;
  final String temaId;
  final String temaTitulo;
  final String cursoNombre;
  final String titulo;
  final String videoId;
  final EstadoClaseDocente estado;
  final int corazones;
  final DateTime creadaEn;

  /// Por qué no se publicó (lo ve el docente).
  final String? motivo;

  const ClaseDocente({
    required this.id,
    required this.docenteUid,
    required this.docenteNombre,
    required this.temaId,
    required this.temaTitulo,
    required this.cursoNombre,
    required this.titulo,
    required this.videoId,
    required this.estado,
    required this.corazones,
    required this.creadaEn,
    this.motivo,
  });

  String get miniatura => miniaturaYoutube(videoId);

  Uri get enlace => Uri.https('www.youtube.com', '/watch', {'v': videoId});
}

/// Las más queridas primero; a igual cantidad, las más nuevas.
List<ClaseDocente> ordenarPorCorazones(Iterable<ClaseDocente> clases) =>
    clases.toList()..sort((a, b) {
      final c = b.corazones.compareTo(a.corazones);
      return c != 0 ? c : b.creadaEn.compareTo(a.creadaEn);
    });

const minTituloClase = 3;
const maxTituloClase = 120;

/// Qué falta para enviar la clase (null si está completa).
String? errorClaseDocente({
  required String? temaId,
  required String titulo,
  required String enlace,
}) {
  if (temaId == null) return 'Elige el curso y el tema de tu clase.';
  final t = titulo.trim();
  if (t.length < minTituloClase) return 'Escribe el título de tu clase.';
  if (t.length > maxTituloClase) return 'El título es demasiado largo.';
  if (idVideoYoutube(enlace) == null) {
    return 'Pega el enlace de tu video de YouTube (puede ser no listado).';
  }
  return null;
}

abstract class RepositorioClasesDocente {
  /// Las publicadas de un tema, las más queridas primero.
  Future<List<ClaseDocente>> delTema(String temaId);

  /// De [claseIds], a cuáles les dio corazón [uid].
  Future<Set<String>> conMiCorazon(String uid, List<String> claseIds);

  Future<void> darCorazon(String claseId, String uid);

  Future<void> quitarCorazon(String claseId, String uid);

  /// Las publicadas de un docente (su página).
  Future<List<ClaseDocente>> deDocente(String docenteUid);

  /// Las que envió el docente, con su estado.
  Future<List<ClaseDocente>> mias(String docenteUid);

  Future<void> enviar({
    required String docenteUid,
    required String docenteNombre,
    required String temaId,
    required String temaTitulo,
    required String cursoNombre,
    required String titulo,
    required String videoId,
  });
}
