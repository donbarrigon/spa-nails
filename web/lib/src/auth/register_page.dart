import 'package:client/client.dart';
import 'package:shared/shared.dart';

import '../core/form_view.dart';
import '../core/page.dart';

/// Registro con correo: crea la cuenta y la sesión, y vuelve al inicio.
void initRegisterPage() {
  final element = query('#register-form');
  if (element == null) return;
  final form = FormView(element, errorId: 'register-error');

  form.onSubmit.listen((_) async {
    final validator = UserRegisterValidator(
      nickname: form.value('nickname'),
      name: form.value('name'),
      email: form.value('email'),
      phone: form.value('phone'),
      password: form.value('password'),
      remember: form.checked('remember'),
    )..prepareForValidation();
    final errors = validator.validate();
    if (errors.isNotEmpty) return form.show(fields: errors);

    form
      ..show()
      ..busy = true;
    try {
      await api('/api/users/auth/register', body: validator.toJson());
      go('/');
    } on ApiException catch (e) {
      final conflict = e.status == 409 ? AuthErrors.registerConflict(e) : const <String, String>{};
      form
        ..busy = false
        ..show(fields: {...e.fields, ...conflict}, message: conflict.isEmpty ? AuthErrors.of(e) : null);
    }
  });
}
