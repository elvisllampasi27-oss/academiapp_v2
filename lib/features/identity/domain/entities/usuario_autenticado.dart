class UsuarioAutenticado {
  final String uid;
  final String? correo;

  /// Nombre que entrega el proveedor (p. ej. Google). Solo se usa para
  /// prellenar el perfil; el nombre oficial vive en [UsuarioAcademiApp].
  final String? nombre;

  const UsuarioAutenticado({
    required this.uid,
    required this.correo,
    this.nombre,
  });
}
