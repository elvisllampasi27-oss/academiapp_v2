enum RolUsuario { estudiante, administrador }

enum EstadoUsuario { activo, inactivo }

class UsuarioAcademiApp {
  final String uid;
  final String correo;
  final String nombre;
  final RolUsuario rol;
  final EstadoUsuario estado;
  final DateTime fechaCreacion;

  /// Carrera a la que postula. Opcional: cuentas antiguas no la tienen.
  final String? carreraPostulada;

  const UsuarioAcademiApp({
    required this.uid,
    required this.correo,
    required this.nombre,
    required this.rol,
    required this.estado,
    required this.fechaCreacion,
    this.carreraPostulada,
  });
}
