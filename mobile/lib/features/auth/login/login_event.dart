import 'package:shared/shared.dart';

sealed class LoginEvent {
  const LoginEvent();
}

final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted(this.form);
  final UserLoginValidator form;
}

final class LoginWithGoogle extends LoginEvent {
  const LoginWithGoogle({required this.remember});
  final bool remember;
}

final class TwoFactorSubmitted extends LoginEvent {
  const TwoFactorSubmitted(this.code);
  final String code;
}

/// Pide otro código; con [method] cambia de canal (correo, WhatsApp o app).
final class TwoFactorResent extends LoginEvent {
  const TwoFactorResent([this.method]);
  final TwoFactorMethod? method;
}

/// Vuelve del segundo factor al formulario de credenciales.
final class TwoFactorCancelled extends LoginEvent {
  const TwoFactorCancelled();
}
