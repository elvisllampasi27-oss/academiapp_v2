/// Aviso que el equipo publica desde el panel ("mañana no hay clase",
/// "nuevo simulacro disponible"). Se ve arriba en el Inicio de la app.
class Aviso {
  final String id;
  final String titulo;
  final String mensaje;

  /// null = para todos; si no, solo para los matriculados en esa versión.
  final String? versionId;

  /// Se destaca y se muestra primero.
  final bool importante;

  /// Pausado = no se muestra, pero no se pierde.
  final bool activo;

  /// Se deja de mostrar desde este momento.
  final DateTime hasta;
  final DateTime? creadoEn;

  const Aviso({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.hasta,
    this.versionId,
    this.importante = false,
    this.activo = true,
    this.creadoEn,
  });

  bool vigenteEn(DateTime ahora) => activo && hasta.isAfter(ahora);

  bool esPara(String? version) => versionId == null || versionId == version;

  Aviso copiar({bool? activo}) => Aviso(
    id: id,
    titulo: titulo,
    mensaje: mensaje,
    hasta: hasta,
    versionId: versionId,
    importante: importante,
    activo: activo ?? this.activo,
    creadoEn: creadoEn,
  );
}

/// Largos permitidos (las reglas de Firestore exigen lo mismo).
const largoTituloAviso = 80;
const largoMensajeAviso = 600;

/// Los avisos que ve un estudiante: vigentes, para él, los importantes
/// primero y luego los más nuevos.
List<Aviso> avisosPara(
  List<Aviso> todos, {
  required String? versionId,
  required DateTime ahora,
}) {
  final epoca = DateTime(2000);
  return [
    for (final a in todos)
      if (a.vigenteEn(ahora) && a.esPara(versionId)) a,
  ]..sort((a, b) {
    if (a.importante != b.importante) return a.importante ? -1 : 1;
    return (b.creadoEn ?? epoca).compareTo(a.creadoEn ?? epoca);
  });
}

abstract class RepositorioAvisos {
  /// Los avisos activos (la app filtra los vencidos y los de otra versión).
  Future<List<Aviso>> activos();
}
