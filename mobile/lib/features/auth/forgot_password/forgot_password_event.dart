sealed class ForgotPasswordEvent {
  const ForgotPasswordEvent();
}

/// Pide el enlace o el código para [user] (correo o teléfono).
final class ForgotSubmitted extends ForgotPasswordEvent {
  const ForgotSubmitted(this.user);
  final String user;
}

/// El código de WhatsApp con la contraseña nueva.
final class ForgotCodeSubmitted extends ForgotPasswordEvent {
  const ForgotCodeSubmitted({required this.code, required this.password, required this.passwordConfirmation});
  final String code;
  final String password;
  final String passwordConfirmation;
}

/// Pide otro código al mismo teléfono.
final class ForgotCodeResent extends ForgotPasswordEvent {
  const ForgotCodeResent();
}

/// Vuelve al paso 1 para usar otro correo o teléfono.
final class ForgotRestarted extends ForgotPasswordEvent {
  const ForgotRestarted();
}
