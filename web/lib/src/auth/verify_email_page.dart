import 'package:client/client.dart';
import 'package:web/web.dart' as web;

import '../components/app_button.dart';
import '../components/message_banner.dart';
import '../core/page.dart';

/// Verificar correo: cuando la persona pulsa el botón envía el token del enlace
/// (`?token=...`) a la API y muestra el estado (`data-state`) que corresponde.
void initVerifyEmailPage() {
  final root = query('#verify-email');
  if (root == null) return;
  final token = Uri.parse(web.window.location.href).queryParameters['token']?.trim() ?? '';
  final reason = query('#verify-email-reason', root)!;
  final error = MessageBanner.byId('verify-email-error');
  final resendError = MessageBanner.byId('verify-email-resend-error');

  void show(String state) => showState(root, state);

  void invalid(String message) {
    reason.textContent = message;
    show('invalid');
  }

  if (token.isEmpty) {
    invalid(
      'El enlace de verificación está incompleto. '
      'Ábrelo nuevamente desde el correo o solicita uno nuevo.',
    );
  }

  final submitElement = query('#verify-email-submit', root)!;
  final submit = AppButton(submitElement);
  submitElement.onClick.listen((_) async {
    error.message = null;
    submit.loading = true;
    try {
      await api('/api/users/auth/verify/email', body: {'token': token});
      show('verified');
    } on ApiException catch (e) {
      switch (e.status) {
        // 404: no existe, ya se usó o venció. 422: el token no tiene el formato.
        case 404 || 422:
          invalid(
            'Este enlace de verificación venció o ya fue utilizado. '
            'Solicita uno nuevo y te lo enviaremos a tu correo electrónico.',
          );
        // 410: cambió el correo después de recibir el enlace.
        case 410:
          invalid(
            'Este enlace corresponde a una dirección de correo anterior. '
            'Solicita uno nuevo para verificar tu correo actual.',
          );
        default:
          error.message = AuthErrors.of(e);
      }
    } finally {
      submit.loading = false;
    }
  });

  if (query('#verify-email-resend', root) case final element?) {
    final resend = AppButton(element);
    element.onClick.listen((_) async {
      resendError.message = null;
      resend.loading = true;
      try {
        await api('/api/users/auth/verify/email/resend');
        show('sent');
      } on ApiException catch (e) {
        switch (e.status) {
          // 409: ya estaba verificado (p. ej. con otro enlace).
          case 409:
            show('verified');
          case 401:
            resendError.message = 'Tu sesión venció. Inicia sesión para solicitar un nuevo enlace de verificación.';
          case 429:
            resendError.message =
                'Solicitaste varios enlaces en poco tiempo. Espera unos minutos antes de intentarlo de nuevo.';
          default:
            resendError.message = AuthErrors.of(e);
        }
      } finally {
        resend.loading = false;
      }
    });
  }
}
