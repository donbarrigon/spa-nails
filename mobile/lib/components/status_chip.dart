import 'package:flutter/material.dart';

import '../core/theme/status_colors.dart';

enum StatusTone { success, warning, neutral, error }

/// Píldora con punto para estados: confirmada, pendiente, verificado...
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<StatusColors>()!;
    final (fg, bg) = switch (tone) {
      StatusTone.success => (status.success, status.successContainer),
      StatusTone.warning => (status.warning, status.warningContainer),
      StatusTone.neutral => (scheme.onTertiaryContainer, scheme.tertiaryContainer),
      StatusTone.error => (scheme.error, scheme.errorContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
