import 'package:flutter/material.dart';

/// Playfair Display (serif) solo para display y headline: títulos y marca.
/// DM Sans para todo lo demás. Las fuentes están en `assets/fonts`.
abstract final class AppText {
  static const display = 'PlayfairDisplay';
  static const body = 'DMSans';

  static const theme = TextTheme(
    displayLarge: TextStyle(fontFamily: display, fontSize: 40, fontWeight: FontWeight.w500, height: 1.1),
    displayMedium: TextStyle(fontFamily: display, fontSize: 36, fontWeight: FontWeight.w500, height: 1.1),
    displaySmall: TextStyle(fontFamily: display, fontSize: 32, fontWeight: FontWeight.w500, height: 1.15),
    headlineLarge: TextStyle(fontFamily: display, fontSize: 28, fontWeight: FontWeight.w500, height: 1.2),
    headlineMedium: TextStyle(fontFamily: display, fontSize: 24, fontWeight: FontWeight.w500, height: 1.2),
    headlineSmall: TextStyle(fontFamily: display, fontSize: 22, fontWeight: FontWeight.w500, height: 1.25),
    titleLarge: TextStyle(fontFamily: body, fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium: TextStyle(fontFamily: body, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
    titleSmall: TextStyle(fontFamily: body, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge: TextStyle(fontFamily: body, fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: TextStyle(fontFamily: body, fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
    bodySmall: TextStyle(fontFamily: body, fontSize: 13, fontWeight: FontWeight.w400, height: 1.45),
    labelLarge: TextStyle(fontFamily: body, fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
    labelMedium: TextStyle(fontFamily: body, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
    labelSmall: TextStyle(fontFamily: body, fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: 0.4),
  );
}
