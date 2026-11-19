import 'package:web/web.dart' as web;

import '../core/page.dart';

/// El `MessageBanner` del HTML: se muestra con un mensaje y se oculta con `null`.
final class MessageBanner {
  MessageBanner(this.element);

  /// El banner con `id` (sin `#`).
  factory MessageBanner.byId(String id) => MessageBanner(query('#$id')!);

  final web.Element element;

  set message(String? message) {
    query('.message-banner__text', element)!.textContent = message ?? '';
    element.toggleAttribute('hidden', message == null || message.isEmpty);
  }
}
