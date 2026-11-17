import 'package:flutter/material.dart';

import '../core/layout.dart';

/// Contenido desplazable de una pantalla, centrado y con ancho máximo para que
/// en tablet y escritorio no se estire de borde a borde. La barra de
/// desplazamiento queda en el borde de la ventana, no del contenido.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 720, this.spacing = 16});

  final List<Widget> children;
  final double maxWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final gutter = switch (context.windowSize) {
            WindowSize.compact => 16.0,
            WindowSize.medium => 24.0,
            WindowSize.expanded => 32.0,
          };
          final side = ((constraints.maxWidth - maxWidth) / 2).clamp(gutter, double.infinity);
          return ListView(
            padding: EdgeInsets.fromLTRB(side, 8, side, 32),
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) SizedBox(height: spacing),
                child,
              ],
            ],
          );
        },
      );
}
