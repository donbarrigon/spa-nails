import 'package:flutter/material.dart';

/// Colores de estado que Material no trae: éxito (confirmada, verificado) y
/// advertencia (pendiente). Neutro y error salen del `ColorScheme`.
/// Se lee con `Theme.of(context).extension<StatusColors>()!`.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
  });

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;

  static const light = StatusColors(
    success: Color(0xFF2E7D5B),
    successContainer: Color(0xFFD7F2E3),
    warning: Color(0xFF9A5800),
    warningContainer: Color(0xFFFFE6C7),
  );

  static const dark = StatusColors(
    success: Color(0xFF7BD3A8),
    successContainer: Color(0xFF1D3D2D),
    warning: Color(0xFFFFB95C),
    warningContainer: Color(0xFF4A2F00),
  );

  @override
  StatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
  }) =>
      StatusColors(
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        warning: warning ?? this.warning,
        warningContainer: warningContainer ?? this.warningContainer,
      );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
    );
  }
}
