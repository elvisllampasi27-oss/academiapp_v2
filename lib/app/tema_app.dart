import 'package:flutter/material.dart';

import '../core/presentation/colores_app.dart';

/// Tema oscuro de la app del estudiante. Las pantallas toman de aquí sus
/// colores y formas, así el diseño se cambia en un solo lugar.
ThemeData temaApp() {
  const esquema = ColorScheme.dark(
    primary: ColoresApp.texto,
    onPrimary: ColoresApp.fondo,
    primaryContainer: Color(0xFF2A2B31),
    onPrimaryContainer: ColoresApp.texto,
    secondary: ColoresApp.ambar,
    onSecondary: Color(0xFF1A1306),
    tertiary: ColoresApp.ambar,
    onTertiary: Color(0xFF1A1306),
    error: ColoresApp.naranja,
    onError: ColoresApp.fondo,
    surface: ColoresApp.fondo,
    onSurface: ColoresApp.texto,
    onSurfaceVariant: ColoresApp.apagado,
    outline: ColoresApp.bordeFuerte,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: ColoresApp.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresApp.fondo,
      foregroundColor: ColoresApp.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: ColoresApp.panel,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: ColoresApp.borde),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoresApp.texto,
        foregroundColor: ColoresApp.fondo,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresApp.texto,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        side: const BorderSide(color: ColoresApp.bordeFuerte),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColoresApp.texto,
      linearTrackColor: ColoresApp.borde,
    ),
    dividerTheme: const DividerThemeData(color: ColoresApp.borde),
  );
}
