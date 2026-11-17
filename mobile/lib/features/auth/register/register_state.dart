import 'package:shared/shared.dart';

sealed class RegisterState {
  const RegisterState();
}

final class RegisterForm extends RegisterState {
  const RegisterForm({this.submitting = false, this.error, this.fields = const {}});

  final bool submitting;
  final String? error;

  /// Error de cada campo, con los nombres del backend.
  final Map<String, String> fields;
}

/// Cuenta creada y sesión iniciada.
final class RegisterDone extends RegisterState {
  const RegisterDone(this.user, {required this.remember});

  final SessionUser user;
  final bool remember;
}
