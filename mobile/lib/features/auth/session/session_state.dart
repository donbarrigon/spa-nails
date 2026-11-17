import 'package:shared/shared.dart';

sealed class SessionState {
  const SessionState();
}

/// Revisando la sesión guardada al abrir la app.
final class SessionChecking extends SessionState {
  const SessionChecking();
}

/// Sin sesión: puede ver lo público.
final class SessionGuest extends SessionState {
  const SessionGuest({this.promptLogin = false, this.offline = false});

  /// Recién abierta la app y sin sesión recordada: se le ofrece iniciar sesión
  /// (con la opción de hacerlo luego).
  final bool promptLogin;

  /// No se pudo revisar la sesión guardada por falta de conexión. La sesión
  /// sigue guardada: se puede reintentar.
  final bool offline;
}

final class SessionActive extends SessionState {
  const SessionActive(this.user, {required this.remember});

  final SessionUser user;
  final bool remember;
}
