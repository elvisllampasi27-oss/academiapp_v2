/// Marca cuándo usó la app el estudiante por última vez. El panel lo usa
/// para avisar de quienes llevan días sin entrar.
abstract class RegistroActividad {
  Future<void> registrar(String uid);
}
