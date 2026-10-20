enum EstadoVersionAcademica {
  preparacion,
  publicada,
  activa,
  cerradaNuevasMatriculas,
  finalizada,
  archivada,
}

class VersionAcademica {
  final String id;
  final String codigo;
  final String nombre;
  final DateTime fechaApertura;
  final DateTime? fechaCorte;
  final EstadoVersionAcademica estado;

  const VersionAcademica({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.fechaApertura,
    required this.estado,
    this.fechaCorte,
  });
}
