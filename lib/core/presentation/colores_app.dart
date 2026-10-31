import 'package:flutter/painting.dart';

/// Paleta de la app del estudiante (diseño "vidrio oscuro").
/// Un solo acento (ámbar); naranja y celeste solo con significado
/// (reforzar / incorrecta y profundizar / correcta).
abstract final class ColoresApp {
  static const fondo = Color(0xFF0B0C10);
  static const texto = Color(0xFFF4F4F5);
  static const apagado = Color(0xFFA1A1AA);
  static const tenue = Color(0xFF8B8B95);

  static const ambar = Color(0xFFF2C14E);
  static const naranja = Color(0xFFFF8A5B);
  static const celeste = Color(0xFF7CC4FF);

  /// Paneles translúcidos planos (sin desenfoque: rápidos en gama baja).
  static const panel = Color(0x0DFFFFFF);
  static const borde = Color(0x1AFFFFFF);
  static const bordeFuerte = Color(0x38FFFFFF);
  static const barra = Color(0xEB16171C);
}
