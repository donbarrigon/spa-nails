import 'package:flutter/material.dart';

/// Paleta del local: blanco como base, gris claro de los muebles en bordes y
/// textos secundarios, fucsia como único color de acción y rosas pastel de apoyo.
abstract final class AppColors {
  static const light = ColorScheme(
    brightness: Brightness.light,
    // Fucsia: botón principal, enlaces, campo activo.
    primary: Color(0xFFC0267A),
    onPrimary: Color(0xFFFFFFFF),
    // Rosa pastel: indicadores, avatar, fondos de apoyo. Nunca como texto.
    primaryContainer: Color(0xFFFFD9E8),
    onPrimaryContainer: Color(0xFF5E0B3A),
    // Malva: acentos suaves.
    secondary: Color(0xFF8B5A70),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFBE3EC),
    onSecondaryContainer: Color(0xFF3A1626),
    // Gris mueble: estados neutros.
    tertiary: Color(0xFF6B6870),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFECEBEF),
    onTertiaryContainer: Color(0xFF26242A),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    // Blanco del local.
    surface: Color(0xFFFFFBFC),
    onSurface: Color(0xFF221A1E),
    onSurfaceVariant: Color(0xFF5C5157),
    surfaceDim: Color(0xFFE8DEE3),
    surfaceBright: Color(0xFFFFFBFC),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFDF5F8),
    surfaceContainer: Color(0xFFF8EFF3),
    surfaceContainerHigh: Color(0xFFF2E8ED),
    surfaceContainerHighest: Color(0xFFECE2E7),
    outline: Color(0xFF8F8288),
    outlineVariant: Color(0xFFE3D7DD),
    inverseSurface: Color(0xFF382E33),
    onInverseSurface: Color(0xFFFDEEF3),
    inversePrimary: Color(0xFFFF8DC4),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    // Sin tinte rosado en superficies elevadas: la separación la dan los bordes.
    surfaceTint: Colors.transparent,
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF8DC4),
    onPrimary: Color(0xFF5E0B3A),
    primaryContainer: Color(0xFF8C1A5A),
    onPrimaryContainer: Color(0xFFFFD9E8),
    secondary: Color(0xFFE6B8CB),
    onSecondary: Color(0xFF44202F),
    secondaryContainer: Color(0xFF5C3445),
    onSecondaryContainer: Color(0xFFFBE3EC),
    tertiary: Color(0xFFC9C6CE),
    onTertiary: Color(0xFF2F2D33),
    tertiaryContainer: Color(0xFF45434A),
    onTertiaryContainer: Color(0xFFECEBEF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF5C1A16),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF171215),
    onSurface: Color(0xFFEEE2E7),
    onSurfaceVariant: Color(0xFFD2C3CA),
    surfaceDim: Color(0xFF171215),
    surfaceBright: Color(0xFF3E363A),
    surfaceContainerLowest: Color(0xFF110D10),
    surfaceContainerLow: Color(0xFF1F191C),
    surfaceContainer: Color(0xFF241D21),
    surfaceContainerHigh: Color(0xFF2E262A),
    surfaceContainerHighest: Color(0xFF393035),
    outline: Color(0xFF9C8D94),
    outlineVariant: Color(0xFF4A3F45),
    inverseSurface: Color(0xFFEEE2E7),
    onInverseSurface: Color(0xFF382E33),
    inversePrimary: Color(0xFFC0267A),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );
}
