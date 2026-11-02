/// Reporte de un problema que manda el estudiante desde la app (una
/// pregunta con la clave equivocada, un video que no carga…). El equipo lo
/// revisa en el panel y le puede responder.
enum TipoReporte {
  preguntaExamen('Pregunta de examen'),
  preguntaPractica('Pregunta de práctica'),
  video('La clase no se ve'),
  material('Separata o material'),
  app('Falla de la app'),
  otro('Otro');

  final String etiqueta;
  const TipoReporte(this.etiqueta);
}

enum EstadoReporte {
  nuevo('Nuevo'),
  enRevision('En revisión'),
  resuelto('Resuelto');

  final String etiqueta;
  const EstadoReporte(this.etiqueta);
}

/// Dónde estaba el estudiante al reportar (para ir directo a corregirlo).
class ContextoReporte {
  final String titulo;
  final String? examenId;
  final String? preguntaId;
  final String? versionId;
  final String? temaId;

  const ContextoReporte({
    required this.titulo,
    this.examenId,
    this.preguntaId,
    this.versionId,
    this.temaId,
  });

  Map<String, String> aMapa() => {
    'titulo': titulo,
    'examenId': ?examenId,
    'preguntaId': ?preguntaId,
    'versionId': ?versionId,
    'temaId': ?temaId,
  };

  factory ContextoReporte.desdeMapa(Map<String, dynamic>? m) => ContextoReporte(
    titulo: (m?['titulo'] as String?) ?? '',
    examenId: m?['examenId'] as String?,
    preguntaId: m?['preguntaId'] as String?,
    versionId: m?['versionId'] as String?,
    temaId: m?['temaId'] as String?,
  );
}

class Reporte {
  final String id;
  final String usuarioId;
  final String nombre;
  final String correo;
  final TipoReporte tipo;
  final String mensaje;
  final ContextoReporte contexto;
  final EstadoReporte estado;
  final DateTime creadoEn;
  final String? respuesta;
  final DateTime? respondidoEn;

  const Reporte({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.correo,
    required this.tipo,
    required this.mensaje,
    required this.contexto,
    required this.estado,
    required this.creadoEn,
    this.respuesta,
    this.respondidoEn,
  });
}

/// Largo permitido del mensaje (las reglas de Firestore exigen lo mismo).
const largoMinimoReporte = 5;
const largoMaximoReporte = 1000;

abstract class RepositorioReportes {
  Future<void> enviar({
    required String uid,
    required String nombre,
    required String correo,
    required TipoReporte tipo,
    required String mensaje,
    required ContextoReporte contexto,
  });

  Future<List<Reporte>> mios(String uid);
}
