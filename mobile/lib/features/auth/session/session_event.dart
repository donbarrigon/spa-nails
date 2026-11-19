import 'package:shared/shared.dart';

sealed class SessionEvent {
  const SessionEvent();
}

/// Al abrir la app: revisa si hay una sesión recordada y sigue viva.
final class SessionChecked extends SessionEvent {
  const SessionChecked();
}

/// Login o registro correctos.
final class SessionStarted extends SessionEvent {
  const SessionStarted(this.user, {required this.remember});

  final SessionUser user;

  /// Guardar la sesión en el dispositivo para no pedir login al volver a abrir.
  final bool remember;
}

/// El backend cambió la cookie (la renovó con otro valor o la borró).
final class SessionCookieChanged extends SessionEvent {
  const SessionCookieChanged(this.cookie);
  final String? cookie;
}

/// El usuario cambió sus datos (perfil, correo, preferencias...): el backend
/// respondió el usuario de la sesión actualizado.
final class SessionUserUpdated extends SessionEvent {
  const SessionUserUpdated(this.user);
  final SessionUser user;
}

final class SessionLogoutRequested extends SessionEvent {
  const SessionLogoutRequested();
}
