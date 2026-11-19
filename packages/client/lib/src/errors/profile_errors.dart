import '../api_exception.dart';

import 'auth_errors.dart';

/// Pasa los errores de las rutas de perfil y cuenta a mensajes en español:
/// los que son de un campo van a ese campo y el resto, como mensaje general.
abstract final class ProfileErrors {
  static const wrongPassword = 'La contraseña no es correcta';

  /// `(mensaje general, errores por campo)`.
  static (String?, Map<String, String>) of(ApiException e) {
    final field = _field(e);
    if (field.isNotEmpty) return (null, field);
    if (e.fields.isNotEmpty) return (null, e.fields);
    return (_message(e), const {});
  }

  static Map<String, String> _field(ApiException e) => switch ((e.status, e.message)) {
        // La contraseña de confirmación: `password` o `current_password` según el formulario.
        (403, _) => const {'password': wrongPassword, 'current_password': wrongPassword},
        (404, 'Invalid or expired code') => const {'code': 'El código no es correcto o ya venció'},
        (409, _) => AuthErrors.registerConflict(e),
        (422, 'This is already your email address') => const {'email': 'Ya es tu correo'},
        (422, 'This is already your phone number') => const {'phone': 'Ya es tu teléfono'},
        (422, 'The new password must be different from the current one') => const {
            'password': 'Debe ser distinta de la actual',
          },
        _ => const {},
      };

  static String _message(ApiException e) => switch ((e.status, e.message)) {
        (401, _) => 'Tu sesión venció. Vuelve a iniciar sesión.',
        (409, 'Your authenticator app is already set up') => 'Tu app de autenticación ya está configurada.',
        (409, _) when e.message.startsWith('Your authenticator app is your two-factor method') =>
          'La app de autenticación es tu método de verificación en dos pasos. Cambia el método antes de configurarla de nuevo.',
        (410, _) => 'El código ya no sirve porque el dato cambió. Pide uno nuevo.',
        (422, _) when e.message.startsWith('Set up your authenticator app') =>
          'Configura la app de autenticación antes de usarla.',
        (422, _) when e.message.startsWith('Verify this email or phone') =>
          'Verifica ese correo o teléfono antes de usarlo para la verificación en dos pasos.',
        _ => AuthErrors.of(e),
      };
}
