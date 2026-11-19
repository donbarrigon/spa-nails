import 'package:client/client.dart';
import 'package:shared/shared.dart';

import '../core/form_view.dart';
import '../core/page.dart';

import 'package:web/web.dart' show ElementEventGetters;

import '../components/message_banner.dart';

/// Paso 2 del login: el código de 6 dígitos (`two_factor_step.html`).
final class TwoFactorStep {
  TwoFactorStep({required this.onCancel}) : form = FormView(query('#two-factor-form')!, errorId: 'two-factor-error') {
    form.onSubmit.listen((_) => _submit());
    query('[data-action="two-factor-back"]', form.form)!.onClick.listen((_) => _cancel());
    query('[data-action="two-factor-resend"]', form.form)!.onClick.listen((_) => _resend());
    for (final button in queryAll('[data-method]', form.form)) {
      final method = TwoFactorMethod.tryParse(button.getAttribute('data-method'))!;
      button.onClick.listen((_) => _resend(method));
    }
  }

  final FormView form;
  final _notice = MessageBanner.byId('two-factor-notice');

  /// Vuelve a las credenciales, con un error si el inicio de sesión venció.
  final void Function({String? error}) onCancel;

  late TwoFactorChallenge _challenge;

  void start(TwoFactorChallenge challenge) {
    form.form.toggleAttribute('hidden', false);
    form.fields['code']!.value = '';
    _show(challenge);
    form.fields['code']!.focus();
  }

  static String _where(TwoFactorMethod method) => switch (method) {
    TwoFactorMethod.email => 'Te enviamos un código de 6 dígitos a tu correo.',
    TwoFactorMethod.whatsapp => 'Te enviamos un código de 6 dígitos por WhatsApp.',
    TwoFactorMethod.totp => 'Escribe el código de 6 dígitos de tu app de autenticación.',
  };

  /// Texto según el método y, en los enlaces, los otros métodos (y "Reenviar" si no es la app).
  void _show(TwoFactorChallenge challenge, {String? notice}) {
    _challenge = challenge;
    query('#two-factor-where')!.textContent = _where(challenge.method);
    query(
      '[data-action="two-factor-resend"]',
      form.form,
    )!.toggleAttribute('hidden', challenge.method == TwoFactorMethod.totp);
    for (final button in queryAll('[data-method]', form.form)) {
      button.toggleAttribute('hidden', button.getAttribute('data-method') == challenge.method.name);
    }
    form.show();
    _notice.message = notice;
  }

  void _cancel({String? error}) {
    form.form.toggleAttribute('hidden', true);
    onCancel(error: error);
  }

  Future<void> _submit() async {
    final validator = LoginTwoFactorValidator(challenge: _challenge.challenge, code: form.value('code'))
      ..prepareForValidation();
    if (validator.validate()['code'] case final error?) return form.show(fields: {'code': error});

    form
      ..show()
      ..busy = true;
    _notice.message = null;
    try {
      await api('/api/users/auth/login/two-factor', body: validator.toJson());
      go('/');
    } on ApiException catch (e) {
      form.busy = false;
      switch (e.status) {
        // El challenge venció o se gastó: hay que repetir el primer paso.
        case 401:
          _cancel(error: AuthErrors.signInExpired);
        case 404:
          form.show(fields: {'code': AuthErrors.ofCode(e)});
        default:
          form.show(message: AuthErrors.ofCode(e));
      }
    }
  }

  Future<void> _resend([TwoFactorMethod? method]) async {
    form.busy = true;
    try {
      final res = await api(
        '/api/users/auth/login/two-factor/resend',
        body: {'challenge': _challenge.challenge, if (method != null) 'method': method.name},
      );
      form.busy = false;
      final challenge = TwoFactorChallenge.fromJson(res.json);
      form.fields['code']!.value = '';
      _show(
        challenge,
        notice: challenge.method == TwoFactorMethod.totp
            ? 'Escribe el código que muestra tu app de autenticación.'
            : 'Te enviamos un código nuevo.',
      );
    } on ApiException catch (e) {
      form.busy = false;
      switch (e.status) {
        case 401:
          _cancel(error: AuthErrors.signInExpired);
        case 429:
          _cancel(error: 'Pediste demasiados códigos. Vuelve a ingresar tus datos.');
        default:
          form.show(message: AuthErrors.ofCode(e));
      }
    }
  }
}
