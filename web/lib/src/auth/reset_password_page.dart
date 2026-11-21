import 'package:client/client.dart';
import 'package:shared/shared.dart';
import 'package:web/web.dart' as web;

import '../core/form_view.dart';
import '../core/page.dart';

/// Restablecer contraseña con el enlace del email (`?token=...`): el token solo
/// se envía cuando la persona guarda la contraseña nueva.
void initResetPasswordPage() {
  final root = query('#reset-password');
  if (root == null) return;
  final form = FormView(query('#reset-form', root)!, errorId: 'reset-error');
  final token = Uri.parse(web.window.location.href).queryParameters['token']?.trim() ?? '';

  void invalid(String message) {
    query('#reset-reason', root)!.textContent = message;
    showState(root, 'invalid');
  }

  if (token.isEmpty) {
    return invalid(
      'El enlace para restablecer la contraseña está incompleto. '
      'Ábrelo nuevamente desde el correo o solicita uno nuevo.',
    );
  }

  form.onSubmit.listen((_) async {
    final validator = ResetPasswordValidator(
      token: token,
      password: form.value('password'),
      passwordConfirmation: form.value('password_confirmation'),
    )..prepareForValidation();
    final errors = validator.validate();
    if (errors.isNotEmpty) return form.show(fields: errors);

    form
      ..show()
      ..busy = true;
    try {
      await api('/api/users/auth/password/reset', body: validator.toJson());
      showState(root, 'done');
    } on ApiException catch (e) {
      form.busy = false;
      switch (e.status) {
        // 404: no existe, ya se usó o venció. 422 sin campos: el token no tiene el formato.
        case 404:
        case 422 when !e.fields.containsKey('password'):
          invalid(
            'Este enlace para restablecer la contraseña venció o ya fue utilizado. '
            'Solicita uno nuevo para continuar.',
          );
        case 410:
          invalid(AuthErrors.ofReset(e));
        default:
          form.show(fields: e.fields, message: AuthErrors.of(e));
      }
    }
  });
}
