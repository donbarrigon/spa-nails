import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';
import 'status_colors.dart';

/// Tema claro y oscuro. Los widgets toman de aquí colores, letras y formas:
/// no se ponen colores ni tamaños fijos en las pantallas.
abstract final class AppTheme {
  static final light = _build(AppColors.light, StatusColors.light);
  static final dark = _build(AppColors.dark, StatusColors.dark);

  /// Botones píldora de 52 de alto.
  static const buttonHeight = 52.0;

  /// Campos de texto.
  static const fieldRadius = 14.0;

  /// Tarjetas: blancas con borde gris y sin sombra, como los muebles del local.
  static const cardRadius = 20.0;

  static ThemeData _build(ColorScheme scheme, StatusColors status) {
    final text = AppText.theme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    const pill = StadiumBorder();
    const buttonSize = Size(64, buttonHeight);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24);
    OutlineInputBorder fieldBorder(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: width == 0 ? BorderSide.none : BorderSide(color: color, width: width),
        );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: AppText.body,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [status],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: text.labelLarge,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: pill,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: fieldBorder(scheme.outline, 0),
        enabledBorder: fieldBorder(scheme.outline, 0),
        disabledBorder: fieldBorder(scheme.outline, 0),
        focusedBorder: fieldBorder(scheme.primary, 2),
        errorBorder: fieldBorder(scheme.error, 1),
        focusedErrorBorder: fieldBorder(scheme.error, 2),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => text.bodyMedium!.copyWith(
            color: states.contains(WidgetState.error)
                ? scheme.error
                : states.contains(WidgetState.focused)
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
          ),
        ),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        errorMaxLines: 3,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surface),
      listTileTheme: ListTileThemeData(
        shape: const StadiumBorder(),
        selectedColor: scheme.onPrimaryContainer,
        selectedTileColor: scheme.primaryContainer,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(fieldRadius)),
      ),
    );
  }
}
