import 'contenido.dart';
import 'recurso.dart';

/// Lo que el estudiante ve al entrar a un tema:
/// qué se enseña (contenidos) y con qué se apoya (recursos).
class MaterialTema {
  final List<Contenido> contenidos;
  final List<Recurso> recursos;

  const MaterialTema({required this.contenidos, required this.recursos});

  bool get estaVacio => contenidos.isEmpty && recursos.isEmpty;
}
