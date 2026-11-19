import 'package:web/web.dart' as web;

import '../core/page.dart';

/// El `AppTextField` del HTML (`components/app_text_field.html`): el bloque
/// `[data-field="name"]` con su input (o select), la ayuda y el error.
final class AppTextField {
  AppTextField(this.root) : _control = root.querySelector('input, select')!;

  /// El campo [name] dentro de [form].
  factory AppTextField.of(web.Element form, String name) => AppTextField(query('[data-field="$name"]', form)!);

  final web.Element root;
  final web.Element _control;

  String get name => root.getAttribute('data-field')!;

  String get value => switch (_control.tagName) {
    'SELECT' => (_control as web.HTMLSelectElement).value,
    _ => (_control as web.HTMLInputElement).value,
  };

  set value(String text) => switch (_control.tagName) {
    'SELECT' => (_control as web.HTMLSelectElement).value = text,
    _ => (_control as web.HTMLInputElement).value = text,
  };

  set enabled(bool enabled) => _control.toggleAttribute('disabled', !enabled);

  /// Mensaje de error del campo; `null` si es válido.
  set error(String? message) {
    final invalid = message != null && message.isNotEmpty;
    root.classList.toggle('app-text-field--invalid', invalid);
    _control.setAttribute('aria-invalid', '$invalid');
    final error = query('.app-text-field__error', root)!
      ..textContent = message ?? ''
      ..toggleAttribute('hidden', !invalid);
    if (invalid) error.setAttribute('role', 'alert');
  }

  void focus() => (_control as web.HTMLElement).focus();

  /// Botones para mostrar u ocultar las contraseñas de la página.
  static void initPasswordToggles() {
    for (final button in queryAll('[data-toggle-password]')) {
      button.onClick.listen((_) {
        final input = button.parentElement!.querySelector('input')! as web.HTMLInputElement;
        final show = input.type == 'password';
        input.type = show ? 'text' : 'password';
        button
          ..setAttribute('aria-pressed', '$show')
          ..setAttribute('aria-label', show ? 'Ocultar contraseña' : 'Mostrar contraseña');
      });
    }
  }
}
