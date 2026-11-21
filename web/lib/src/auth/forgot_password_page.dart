import 'package:client/client.dart';
import 'package:shared/shared.dart';
import 'package:web/web.dart' show ElementEventGetters;

import '../components/message_banner.dart';
import '../core/form_view.dart';
import '../core/page.dart';

/// Recuperar contraseña: correo o teléfono → enlace por correo (`sent`) o código
/// por WhatsApp con la contraseña nueva (`code`) → listo (`done`).
void initForgotPasswordPage() {
  final root = query('#forgot-password');
  if (root == null) return;
  final request = FormView(query('#forgot-form', root)!, errorId: 'forgot-error');
  final reset = FormView(query('#forgot-code-form', root)!, errorId: 'forgot-code-error');
  final notice = MessageBanner.byId('forgot-code-notice');

  /// El correo o teléfono normalizado al que se envió (el teléfono va en el paso del código).
  var user = '';

  Future<void> send(FormView form, {required bool resend}) async {
    final validator = ForgotPasswordValidator(user: resend ? user : form.value('user'))..prepareForValidation();
    final errors = validator.validate();
    if (errors.isNotEmpty) return form.show(fields: errors);

    form
      ..show()
      ..busy = true;
    notice.message = null;
    try {
      final res = await api('/api/users/auth/password/forgot', body: validator.toJson());
      form.busy = false;
      user = validator.user;
      for (final slot in queryAll('[data-slot="user"]', root)) {
        slot.textContent = user;
      }
      if (TwoFactorMethod.tryParse(res.json['method']) == TwoFactorMethod.whatsapp) {
        if (resend) {
          notice.message = 'Te enviamos un código nuevo por WhatsApp.';
        } else {
          reset.fields['code']!.value = '';
          reset.fields['password']!.value = '';
          reset.fields['password_confirmation']!.value = '';
          reset.show();
          showState(root, 'code');
          reset.fields['code']!.focus();
        }
      } else {
        showState(root, 'sent');
      }
    } on ApiException catch (e) {
      form
        ..busy = false
        ..show(fields: e.fields, message: AuthErrors.ofReset(e));
    }
  }

  request.onSubmit.listen((_) => send(request, resend: false));

  reset.onSubmit.listen((_) async {
    final validator = ResetPasswordCodeValidator(
      phone: user,
      code: reset.value('code'),
      password: reset.value('password'),
      passwordConfirmation: reset.value('password_confirmation'),
    )..prepareForValidation();
    final errors = validator.validate();
    if (errors.isNotEmpty) return reset.show(fields: errors);

    reset
      ..show()
      ..busy = true;
    notice.message = null;
    try {
      await api('/api/users/auth/password/reset/code', body: validator.toJson());
      showState(root, 'done');
    } on ApiException catch (e) {
      reset.busy = false;
      switch (e.status) {
        case 404:
          reset.show(fields: {'code': 'El código no es correcto o ya venció.'});
        default:
          reset.show(fields: e.fields, message: AuthErrors.ofReset(e));
      }
    }
  });

  query('[data-action="forgot-resend"]', root)!.onClick.listen((_) => send(reset, resend: true));

  for (final button in queryAll('[data-action="forgot-restart"]', root)) {
    button.onClick.listen((_) {
      request.show();
      showState(root, 'request');
      request.fields['user']!.focus();
    });
  }
}
