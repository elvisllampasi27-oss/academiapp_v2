import 'package:flutter/material.dart';

/// Colores del panel. Hay cuatro paletas formales; se elige en el menú de
/// la cuenta y se recuerda en esta computadora.
@immutable
class PaletaPanel extends ThemeExtension<PaletaPanel> {
  final String id;
  final String nombre;

  final Color fondo;
  final Color barra;
  final Color dialogo;
  final Color texto;
  final Color apagado;
  final Color tenue;

  /// Botón principal, selección y lo que pide acción.
  final Color acento;
  final Color sobreAcento;

  /// Datos buenos o informativos (dominio alto, matrícula activa).
  final Color secundario;

  /// Alertas (sin actividad, suspendido, dominio bajo).
  final Color alerta;

  static const panel = Color(0x0AFFFFFF);
  static const borde = Color(0x1AFFFFFF);
  static const bordeFuerte = Color(0x2EFFFFFF);
  static const linea = Color(0x0FFFFFFF);

  const PaletaPanel({
    required this.id,
    required this.nombre,
    required this.fondo,
    required this.barra,
    required this.dialogo,
    required this.texto,
    required this.apagado,
    required this.tenue,
    required this.acento,
    required this.sobreAcento,
    required this.secundario,
    required this.alerta,
  });

  static const marino = PaletaPanel(
    id: 'marino',
    nombre: 'Azul marino y café',
    fondo: Color(0xFF0A1322),
    barra: Color(0xFF0D182B),
    dialogo: Color(0xFF132036),
    texto: Color(0xFFEEF2F7),
    apagado: Color(0xFF9EABBF),
    tenue: Color(0xFF8391A6),
    acento: Color(0xFFC99D6B),
    sobreAcento: Color(0xFF1F140A),
    secundario: Color(0xFF8DB4E2),
    alerta: Color(0xFFE58A6E),
  );

  static const verdeAzulado = PaletaPanel(
    id: 'teal',
    nombre: 'Verde azulado',
    fondo: Color(0xFF07191B),
    barra: Color(0xFF0A2023),
    dialogo: Color(0xFF102B2E),
    texto: Color(0xFFECF5F4),
    apagado: Color(0xFF97B2B0),
    tenue: Color(0xFF7C9997),
    acento: Color(0xFF3FBFAE),
    sobreAcento: Color(0xFF03201C),
    secundario: Color(0xFF93C8E6),
    alerta: Color(0xFFEE8C70),
  );

  static const cafe = PaletaPanel(
    id: 'cafe',
    nombre: 'Café',
    fondo: Color(0xFF17110C),
    barra: Color(0xFF1D1610),
    dialogo: Color(0xFF271E16),
    texto: Color(0xFFF5EFE8),
    apagado: Color(0xFFB5A796),
    tenue: Color(0xFF9A8B7A),
    acento: Color(0xFFD7A56D),
    sobreAcento: Color(0xFF24170A),
    secundario: Color(0xFFE6CDA8),
    alerta: Color(0xFFE8835F),
  );

  static const cafeVerde = PaletaPanel(
    id: 'bosque',
    nombre: 'Café con verde',
    fondo: Color(0xFF11140F),
    barra: Color(0xFF161A13),
    dialogo: Color(0xFF1E2319),
    texto: Color(0xFFF1F2EA),
    apagado: Color(0xFFAAAF9E),
    tenue: Color(0xFF8E9381),
    acento: Color(0xFF8CC28A),
    sobreAcento: Color(0xFF0E1F0D),
    secundario: Color(0xFFD2A675),
    alerta: Color(0xFFE58A6E),
  );

  static const todas = [marino, verdeAzulado, cafe, cafeVerde];

  static PaletaPanel porId(String? id) =>
      todas.where((p) => p.id == id).firstOrNull ?? marino;

  static PaletaPanel de(BuildContext context) =>
      Theme.of(context).extension<PaletaPanel>() ?? marino;

  @override
  PaletaPanel copyWith() => this;

  @override
  PaletaPanel lerp(covariant PaletaPanel? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

ThemeData temaPanel(PaletaPanel p) {
  final redondeado = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  OutlineInputBorder bordeCampo(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: p.acento,
      onPrimary: p.sobreAcento,
      secondary: p.secundario,
      onSecondary: p.fondo,
      tertiary: p.acento,
      onTertiary: p.sobreAcento,
      error: p.alerta,
      onError: p.fondo,
      surface: p.fondo,
      onSurface: p.texto,
      onSurfaceVariant: p.apagado,
      surfaceContainerHigh: p.dialogo,
      surfaceContainerHighest: p.dialogo,
      outline: PaletaPanel.bordeFuerte,
      outlineVariant: PaletaPanel.borde,
    ),
    scaffoldBackgroundColor: p.fondo,
    extensions: [p],
    cardTheme: CardThemeData(
      color: PaletaPanel.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: PaletaPanel.borde),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.dialogo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: PaletaPanel.bordeFuerte),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.acento,
        foregroundColor: p.sobreAcento,
        minimumSize: const Size(40, 42),
        shape: redondeado,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.texto,
        minimumSize: const Size(40, 42),
        shape: redondeado,
        side: const BorderSide(color: PaletaPanel.bordeFuerte),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.apagado),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PaletaPanel.panel,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: p.apagado),
      hintStyle: TextStyle(color: p.tenue),
      border: bordeCampo(PaletaPanel.bordeFuerte),
      enabledBorder: bordeCampo(PaletaPanel.bordeFuerte),
      focusedBorder: bordeCampo(p.acento),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: p.acento,
      side: const BorderSide(color: PaletaPanel.bordeFuerte),
      labelStyle: TextStyle(color: p.texto, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(
        color: p.sobreAcento,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: p.sobreAcento,
      shape: const StadiumBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.dialogo,
      contentTextStyle: TextStyle(color: p.texto),
      behavior: SnackBarBehavior.floating,
    ),
    popupMenuTheme: PopupMenuThemeData(color: p.dialogo),
    dividerTheme: const DividerThemeData(color: PaletaPanel.linea, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.acento,
      linearTrackColor: PaletaPanel.borde,
    ),
  );
}
