import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto relleno, con etiqueta y error. Si [password] es verdadero
/// oculta el texto y agrega el botón para mostrarlo.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.password = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.suffix,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;

  /// Mensaje de error del campo; `null` si es válido.
  final String? error;
  final bool password;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Para campos [readOnly] que abren un selector (ej. la fecha).
  final VoidCallback? onTap;

  /// Ícono o botón al final del campo. Los de contraseña ya traen el suyo.
  final Widget? suffix;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: widget.password && _obscured,
        enableSuggestions: !widget.password,
        autocorrect: !widget.password,
        keyboardType: widget.password ? TextInputType.visiblePassword : widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.enabled ? widget.autofillHints : null,
        inputFormatters: widget.inputFormatters,
        maxLength: widget.maxLength,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        textCapitalization: widget.textCapitalization,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onTap: widget.onTap,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          helperText: widget.helper,
          helperMaxLines: 2,
          errorText: widget.error,
          counterText: '',
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscured = !_obscured),
                )
              : widget.suffix,
        ),
      );
}
