import 'package:flutter/widgets.dart';

/// Permite a la pantalla del tema manejar el reproductor: pausar (al abrir
/// las dudas) e ir a un segundo (volver a la parte que se saltó).
class ControlClase {
  VoidCallback? _pausar;
  void Function(double segundos)? _irA;

  void vincular({
    required VoidCallback pausar,
    required void Function(double segundos) irA,
  }) {
    _pausar = pausar;
    _irA = irA;
  }

  void desvincular() {
    _pausar = null;
    _irA = null;
  }

  void pausar() => _pausar?.call();

  void irA(double segundos) => _irA?.call(segundos);
}

/// Lectura periódica del reproductor, en segundos.
typedef AlAvanzarClase = void Function(double posicion, double duracion);

/// Construye el reproductor de la clase. Se inyecta en la pantalla del tema
/// para poder probarla sin un reproductor real.
typedef ConstructorReproductor = Widget Function({
  required String videoId,
  required double inicio,
  required ControlClase control,
  required AlAvanzarClase alAvanzar,
});
