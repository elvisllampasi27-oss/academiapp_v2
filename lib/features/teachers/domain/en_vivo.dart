enum PlataformaEnVivo {
  tiktok('TikTok', ['tiktok.com']),
  meet('Google Meet', ['meet.google.com']),
  youtube('YouTube', ['youtube.com', 'youtu.be']),
  otra('Otra', []);

  final String etiqueta;

  /// Dominios que se aceptan para el enlace (vacío: cualquiera https).
  final List<String> dominios;

  const PlataformaEnVivo(this.etiqueta, this.dominios);

  static PlataformaEnVivo? desde(Object? valor) =>
      values.where((e) => e.name == valor).firstOrNull;

  bool acepta(Uri enlace) {
    if (dominios.isEmpty) return true;
    final host = enlace.host.toLowerCase();
    return dominios.any((d) => host == d || host.endsWith('.$d'));
  }
}

enum EstadoEnVivo {
  pendiente('En revisión'),
  aprobado('Aprobado'),
  rechazado('No aprobado');

  final String etiqueta;

  const EstadoEnVivo(this.etiqueta);

  static EstadoEnVivo? desde(Object? valor) =>
      values.where((e) => e.name == valor).firstOrNull;
}

enum MomentoEnVivo { proximo, enVivo, terminado }

/// Transmisión que programa un docente aprobado (TikTok, Meet, YouTube…).
/// Los alumnos la ven en Inicio, con cuenta regresiva, cuando el
/// administrador la aprueba. No se puede saber si de verdad está
/// transmitiendo: se muestra "en vivo" durante el horario aprobado.
class EnVivo {
  final String id;
  final String docenteUid;
  final String docenteNombre;
  final String titulo;
  final PlataformaEnVivo plataforma;
  final String enlace;
  final DateTime inicio;

  /// Fin del horario (o cuando el administrador lo terminó).
  final DateTime fin;
  final String? cursoNombre;
  final EstadoEnVivo estado;
  final String? motivo;

  const EnVivo({
    required this.id,
    required this.docenteUid,
    required this.docenteNombre,
    required this.titulo,
    required this.plataforma,
    required this.enlace,
    required this.inicio,
    required this.fin,
    required this.estado,
    this.cursoNombre,
    this.motivo,
  });

  MomentoEnVivo momento(DateTime ahora) {
    if (!ahora.isBefore(fin)) return MomentoEnVivo.terminado;
    if (ahora.isBefore(inicio)) return MomentoEnVivo.proximo;
    return MomentoEnVivo.enVivo;
  }

  /// Se puede entrar un poco antes (en Meet, el docente admite).
  bool sePuedeUnir(DateTime ahora) =>
      momento(ahora) == MomentoEnVivo.enVivo ||
      (momento(ahora) == MomentoEnVivo.proximo &&
          inicio.difference(ahora) <= const Duration(minutes: 10));
}

/// Los que están en vivo primero; luego los próximos, del más cercano.
/// Los terminados no se muestran.
List<EnVivo> paraMostrar(Iterable<EnVivo> enVivos, DateTime ahora) {
  final lista = [
    for (final e in enVivos)
      if (e.momento(ahora) != MomentoEnVivo.terminado) e,
  ];
  int peso(EnVivo e) => e.momento(ahora) == MomentoEnVivo.enVivo ? 0 : 1;
  return lista..sort((a, b) {
    final p = peso(a).compareTo(peso(b));
    return p != 0 ? p : a.inicio.compareTo(b.inicio);
  });
}

/// "02:14:09", o "3 d 02:14:09" si falta más de un día.
String cuentaRegresiva(Duration falta) {
  if (falta.isNegative) return '00:00:00';
  String dos(int n) => n.toString().padLeft(2, '0');
  final dias = falta.inDays;
  final hms =
      '${dos(falta.inHours % 24)}:${dos(falta.inMinutes % 60)}:'
      '${dos(falta.inSeconds % 60)}';
  return dias > 0 ? '$dias d $hms' : hms;
}

/// Duraciones que se pueden elegir (minutos).
const duracionesEnVivo = [30, 45, 60, 90, 120, 180];

/// Hasta cuántos días antes se puede programar.
const diasMaximosEnVivo = 30;

/// Qué falta para programarlo (null si está completo).
String? errorEnVivo({
  required String titulo,
  required PlataformaEnVivo plataforma,
  required String enlace,
  required DateTime inicio,
  required DateTime ahora,
}) {
  final t = titulo.trim();
  if (t.length < 3) return 'Escribe el título del en vivo.';
  if (t.length > 120) return 'El título es demasiado largo.';
  final uri = Uri.tryParse(enlace.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return 'Pega el enlace de tu en vivo (empieza con https://).';
  }
  if (!plataforma.acepta(uri)) {
    return 'Ese enlace no es de ${plataforma.etiqueta}.';
  }
  if (!inicio.isAfter(ahora.add(const Duration(minutes: 5)))) {
    return 'Elige una fecha y hora que todavía no pasó.';
  }
  if (inicio.isAfter(ahora.add(const Duration(days: diasMaximosEnVivo)))) {
    return 'Prográmalo con menos de $diasMaximosEnVivo días de anticipación.';
  }
  return null;
}

abstract class RepositorioEnVivos {
  /// Aprobados que todavía no terminan (para Inicio).
  Future<List<EnVivo>> vigentes();

  /// Aprobados de un docente que todavía no terminan (su página).
  Future<List<EnVivo>> delDocente(String docenteUid);

  /// Los que programó el docente, con su estado.
  Future<List<EnVivo>> mios(String docenteUid);

  Future<void> programar({
    required String docenteUid,
    required String docenteNombre,
    required String titulo,
    required PlataformaEnVivo plataforma,
    required String enlace,
    required DateTime inicio,
    required int duracionMinutos,
    String? cursoNombre,
  });

  /// El docente lo retira (antes de que termine).
  Future<void> cancelar(EnVivo enVivo);
}
