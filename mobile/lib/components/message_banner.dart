import 'package:flutter/material.dart';

enum MessageTone { error, info }

/// Mensaje en línea dentro de un formulario o pantalla (error del servidor,
/// "te enviamos un código nuevo"...). Para avisos pasajeros usar un SnackBar.
class MessageBanner extends StatelessWidget {
  const MessageBanner(this.message, {super.key, this.tone = MessageTone.error, this.action});

  final String message;
  final MessageTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg, icon) = switch (tone) {
      MessageTone.error => (scheme.onErrorContainer, scheme.errorContainer, Icons.error_outline),
      MessageTone.info => (scheme.onSecondaryContainer, scheme.secondaryContainer, Icons.info_outline),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Icon(icon, size: 20, color: fg),
            Expanded(
              child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg)),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
