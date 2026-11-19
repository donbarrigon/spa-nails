import 'package:web/web.dart' as web;

import '../components/app_button.dart';
import '../components/app_text_field.dart';
import '../components/message_banner.dart';
import 'page.dart';

/// Un formulario de la página: lee sus campos, lo bloquea mientras se envía y
/// muestra los errores (por campo y el mensaje general).
final class FormView {
  FormView(this.form, {required String errorId})
    : error = MessageBanner.byId(errorId),
      _submit = AppButton(query('button[type="submit"]', form)!),
      fields = {
        for (final root in queryAll('[data-field]', form)) root.getAttribute('data-field')!: AppTextField(root),
      };

  final web.Element form;
  final MessageBanner error;
  final Map<String, AppTextField> fields;
  final AppButton _submit;

  /// Envíos del formulario (Enter o el botón), sin recargar la página.
  Stream<web.Event> get onSubmit => form.onSubmit.map((e) {
    e.preventDefault();
    return e;
  });

  String value(String name) => fields[name]!.value;

  bool checked(String name) => (query('input[name="$name"]', form)! as web.HTMLInputElement).checked;

  /// Mientras envía: indicador en el botón y todo desactivado.
  set busy(bool busy) {
    _submit.loading = busy;
    for (final control in queryAll('input, select, button', form)) {
      if (control.hasAttribute('data-keep-disabled')) continue;
      control.toggleAttribute('disabled', busy);
    }
  }

  /// Muestra [fields] en sus campos (borra los demás) y [message] arriba del botón.
  /// Enfoca el primer campo con error.
  void show({Map<String, String> fields = const {}, String? message}) {
    AppTextField? first;
    for (final MapEntry(key: name, value: field) in this.fields.entries) {
      field.error = fields[name];
      if (fields.containsKey(name)) first ??= field;
    }
    error.message = message;
    first?.focus();
  }
}
