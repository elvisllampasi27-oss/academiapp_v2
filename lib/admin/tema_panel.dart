import 'package:flutter/material.dart';

/// Colores del panel: grafito oscuro con acento ámbar (un solo tema).
@immutable
class PaletaPanel extends ThemeExtension<PaletaPanel> {
  final Color fondo;
  final Color barra;
  final Color dialogo;
  final Color texto;
  final Color apagado;
  final Color tenue;

  /// Botón principal, selección y la serie principal de los gráficos.
  final Color acento;
  final Color sobreAcento;

  /// Lo que está bien (matrícula activa, dominio alto, "al día").
  final Color secundario;

  /// Alertas (sin actividad, suspendido, dominio bajo).
  final Color alerta;

  /// Degradado dorado de los títulos grandes.
  final List<Color> dorado;

  static const panel = Color(0x0AFFFFFF);
  static const borde = Color(0x17FFFFFF);
  static const bordeFuerte = Color(0x2BFFFFFF);
  static const linea = Color(0x0FFFFFFF);

  const PaletaPanel({
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
    required this.dorado,
  });

  static const ambar = PaletaPanel(
    fondo: Color(0xFF111215),
    barra: Color(0xFF15161A),
    dialogo: Color(0xFF1C1D22),
    texto: Color(0xFFEDEDEF),
    apagado: Color(0xFFA0A1A8),
    tenue: Color(0xFF85868E),
    acento: Color(0xFFE8913A),
    sobreAcento: Color(0xFF1C1206),
    secundario: Color(0xFF5FCF8A),
    alerta: Color(0xFFEF6F5E),
    dorado: [Color(0xFFF2C487), Color(0xFFD98A3D)],
  );

  static PaletaPanel de(BuildContext context) =>
      Theme.of(context).extension<PaletaPanel>() ?? ambar;

  @override
  PaletaPanel copyWith() => this;

  @override
  PaletaPanel lerp(covariant PaletaPanel? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

ThemeData temaPanel([PaletaPanel p = PaletaPanel.ambar]) {
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
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: PaletaPanel.borde),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.dialogo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.dialogo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PaletaPanel.bordeFuerte),
      ),
      textStyle: TextStyle(color: p.texto, fontSize: 12),
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
