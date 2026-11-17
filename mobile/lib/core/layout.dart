import 'package:flutter/widgets.dart';

/// Tamaño de ventana según Material 3: celular, tablet o escritorio.
/// Se decide por el ancho disponible, no por el tipo de dispositivo: una
/// tablet en vertical o una ventana angosta de escritorio son `compact`.
enum WindowSize {
  /// Menos de 600: celular.
  compact,

  /// De 600 a 839: tablet en vertical, ventana mediana.
  medium,

  /// 840 o más: tablet en horizontal, escritorio.
  expanded;

  static WindowSize of(double width) => switch (width) {
        < 600 => compact,
        < 840 => medium,
        _ => expanded,
      };
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize => WindowSize.of(MediaQuery.sizeOf(this).width);
}
