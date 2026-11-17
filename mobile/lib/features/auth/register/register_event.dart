import 'package:shared/shared.dart';

import '../../../core/google_auth.dart';

/// Registro tras un login con Google sin cuenta: el email sale de Google.
final class GoogleRegistration {
  const GoogleRegistration({required this.identity, required this.remember});

  final GoogleIdentity identity;
  final bool remember;
}

sealed class RegisterEvent {
  const RegisterEvent();
}

final class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted(this.form);
  final UserRegisterValidator form;
}

final class GoogleRegisterSubmitted extends RegisterEvent {
  const GoogleRegisterSubmitted(this.form);
  final GoogleRegisterValidator form;
}
