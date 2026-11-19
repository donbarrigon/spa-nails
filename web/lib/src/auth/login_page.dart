import 'package:client/client.dart';
import 'package:shared/shared.dart';

import '../core/form_view.dart';
import '../core/page.dart';
import 'two_factor_step.dart';

/// Login: credenciales → segundo factor si la cuenta lo tiene → inicio.
void initLoginPage() {
  final element = query('#login-form');
  if (element == null) return;
  final form = FormView(element, errorId: 'login-error');

  final twoFactor = TwoFactorStep(
    onCancel: ({String? error}) {
      form.form.toggleAttribute('hidden', false);
      form.show(message: error);
    },
  );

  form.onSubmit.listen((_) async {
    final validator = UserLoginValidator(
      user: form.value('user'),
      password: form.value('password'),
      remember: form.checked('remember'),
    )..prepareForValidation();
    final errors = validator.validate();
    if (errors.isNotEmpty) return form.show(fields: errors);

    form
      ..show()
      ..busy = true;
    try {
      final res = await api('/api/users/auth/login', body: validator.toJson());
      if (res.status == 202) {
        form
          ..busy = false
          ..form.toggleAttribute('hidden', true);
        twoFactor.start(TwoFactorChallenge.fromJson(res.json));
      } else {
        go('/');
      }
    } on ApiException catch (e) {
      form
        ..busy = false
        ..show(fields: e.fields, message: AuthErrors.of(e));
    }
  });
}
