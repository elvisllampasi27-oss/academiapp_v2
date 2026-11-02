/// Error del tutor con un mensaje listo para mostrar al estudiante.
class ErrorTutor implements Exception {
  final String mensaje;

  const ErrorTutor(this.mensaje);

  @override
  String toString() => mensaje;
}
