import 'package:flutter/material.dart';

/// Tarjeta con un título, filas `etiqueta — valor` y, opcional, una acción
/// junto al título (ej. "Editar") y contenido extra al final ([footer]).
class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.title,
    this.icon,
    this.action,
    this.rows = const [],
    this.footer = const [],
  });

  final String title;
  final IconData? icon;
  final Widget? action;

  /// Etiqueta y valor (texto o un `StatusChip`).
  final List<(String, Widget)> rows;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                spacing: 10,
                children: [
                  if (icon != null) Icon(icon, size: 20, color: scheme.primary),
                  Expanded(child: Text(title, style: text.titleMedium)),
                  ?action,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (label, value)) in rows.indexed) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        spacing: 16,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: DefaultTextStyle.merge(
                                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                textAlign: TextAlign.right,
                                child: value,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (footer.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final (i, child) in footer.indexed) ...[
                      if (i > 0) const SizedBox(height: 10),
                      child,
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
