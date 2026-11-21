sealed class ForgotPasswordState {
  const ForgotPasswordState();
}

/// Paso 1: el correo o teléfono de la cuenta.
final class ForgotRequest extends ForgotPasswordState {
  const ForgotRequest({this.submitting = false, this.error, this.fields = const {}});

  final bool submitting;
  final String? error;

  /// Error de cada campo, con los nombres del backend (`user`).
  final Map<String, String> fields;
}

/// Con correo: le llegó un enlace que abre la web para crear la contraseña.
final class ForgotEmailSent extends ForgotPasswordState {
  const ForgotEmailSent(this.email);
  final String email;
}

/// Con teléfono: el código de WhatsApp y la contraseña nueva.
final class ForgotCode extends ForgotPasswordState {
  const ForgotCode({required this.phone, this.submitting = false, this.error, this.fields = const {}, this.notice});

  /// Normalizado, como lo pide `password/reset/code`.
  final String phone;
  final bool submitting;
  final String? error;

  /// `code` y `password`.
  final Map<String, String> fields;

  /// Aviso informativo, ej. "Te enviamos un código nuevo".
  final String? notice;
}

/// Contraseña cambiada: el backend cerró todas las sesiones.
final class ForgotDone extends ForgotPasswordState {
  const ForgotDone();
}
