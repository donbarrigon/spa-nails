import 'package:shared/shared.dart';

import '../../../core/google_auth.dart';

sealed class LoginState {
  const LoginState();
}

/// Paso 1: correo o teléfono y contraseña (o Google).
final class LoginCredentials extends LoginState {
  const LoginCredentials({this.submitting = false, this.error, this.fields = const {}});

  final bool submitting;

  /// Error general del formulario.
  final String? error;

  /// Error de cada campo, con los nombres del backend (`user`, `password`).
  final Map<String, String> fields;
}

/// Paso 2: el código del segundo factor.
final class LoginTwoFactor extends LoginState {
  const LoginTwoFactor({
    required this.challenge,
    required this.remember,
    this.submitting = false,
    this.codeError,
    this.error,
    this.notice,
  });

  final TwoFactorChallenge challenge;
  final bool remember;
  final bool submitting;

  /// Error del campo código: vacío, formato o incorrecto.
  final String? codeError;

  /// Error general: sin conexión, demasiados intentos...
  final String? error;

  /// Aviso informativo, ej. "Te enviamos un código nuevo".
  final String? notice;

  /// Los mensajes no se arrastran: cada estado nuevo trae solo los suyos.
  LoginTwoFactor copyWith({
    TwoFactorChallenge? challenge,
    bool submitting = false,
    String? codeError,
    String? error,
    String? notice,
  }) =>
      LoginTwoFactor(
        challenge: challenge ?? this.challenge,
        remember: remember,
        submitting: submitting,
        codeError: codeError,
        error: error,
        notice: notice,
      );
}

/// Sesión iniciada.
final class LoginDone extends LoginState {
  const LoginDone(this.user, {required this.remember});

  final SessionUser user;
  final bool remember;
}

/// Ese Google no tiene cuenta: hay que completar el registro.
final class LoginNeedsGoogleRegistration extends LoginState {
  const LoginNeedsGoogleRegistration(this.identity, {required this.remember});

  final GoogleIdentity identity;
  final bool remember;
}
