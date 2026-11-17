import 'package:flutter/material.dart';

enum _Variant { primary, outlined, text }

/// Botón de la app. Ocupa todo el ancho disponible salvo [expand] = false.
///
/// Regla de diseño: un solo [AppButton] primario (fucsia) por pantalla; las
/// demás acciones van con [AppButton.outlined] o [AppButton.text].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : _variant = _Variant.primary;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : _variant = _Variant.outlined;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : _variant = _Variant.text;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Muestra un indicador y desactiva el botón mientras dura la acción.
  final bool loading;
  final bool expand;
  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    final onPressed = loading ? null : this.onPressed;
    final Widget child = loading
        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);
    final Widget? iconWidget = icon == null || loading ? null : Icon(icon, size: 20);

    final Widget button = switch (_variant) {
      _Variant.primary => iconWidget == null
          ? FilledButton(onPressed: onPressed, child: child)
          : FilledButton.icon(onPressed: onPressed, icon: iconWidget, label: child),
      _Variant.outlined => iconWidget == null
          ? OutlinedButton(onPressed: onPressed, child: child)
          : OutlinedButton.icon(onPressed: onPressed, icon: iconWidget, label: child),
      _Variant.text => iconWidget == null
          ? TextButton(onPressed: onPressed, child: child)
          : TextButton.icon(onPressed: onPressed, icon: iconWidget, label: child),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
