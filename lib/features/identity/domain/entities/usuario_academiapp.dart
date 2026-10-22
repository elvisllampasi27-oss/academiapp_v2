enum RolUsuario { estudiante, administrador }

enum EstadoUsuario { activo, inactivo }

class UsuarioAcademiApp {
  final String uid;
  final String correo;
  final String nombre;
  final RolUsuario rol;
  final EstadoUsuario estado;
  final DateTime fechaCreacion;

  const UsuarioAcademiApp({
    required this.uid,
    required this.correo,
    required this.nombre,
    required this.rol,
    required this.estado,
    required this.fechaCreacion,
  });
}
