import 'package:client/client.dart';
import 'package:flutter/foundation.dart';

import '../../../core/bloc/bloc.dart';
import '../../../core/google_auth.dart';
import '../../../core/session_storage.dart';
import 'session_event.dart';
import 'session_state.dart';

export 'session_event.dart';
export 'session_state.dart';

/// Sesión de toda la app. Vive encima de `MaterialApp`.
///
/// La cookie solo se guarda en el dispositivo con "Recordarme"; sin eso queda
/// en memoria y al cerrar la app se pierde (y al abrir se ofrece el login).
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc({
    required this._api,
    required this._userApi,
    required this._storage,
    required this._google,
  }) : super(const SessionChecking()) {
    _api.onSessionCookieChanged = (cookie) => add(SessionCookieChanged(cookie));
  }

  final ApiClient _api;
  final UserApi _userApi;
  final SessionStorage _storage;
  final GoogleAuth _google;

  @override
  Stream<SessionState> mapEventToState(SessionEvent event) async* {
    switch (event) {
      case SessionChecked():
        yield* _check();

      case SessionStarted(:final user, :final remember):
        final cookie = _api.sessionCookie;
        if (remember && cookie != null) {
          await _storage.write(cookie);
        } else {
          await _storage.clear();
        }
        yield SessionActive(user, remember: remember);

      case SessionCookieChanged(:final cookie):
        if (state case SessionActive(remember: true) when cookie != null) {
          await _storage.write(cookie);
        }

      case SessionLogoutRequested():
        try {
          await _userApi.logout();
        } on ApiException catch (e) {
          // Sin red igual se cierra en el dispositivo; el backend la vence sola.
          debugPrint('logout: $e');
        }
        _api.sessionCookie = null;
        await _storage.clear();
        await _google.signOut().catchError((Object e) => debugPrint('google signOut: $e'));
        yield const SessionGuest();
    }
  }

  Stream<SessionState> _check() async* {
    if (state is! SessionChecking) yield const SessionChecking();

    _api.sessionCookie ??= await _storage.read();
    if (_api.sessionCookie == null) {
      yield const SessionGuest(promptLogin: true);
      return;
    }

    try {
      final user = await _userApi.me();
      if (user != null) {
        yield SessionActive(user, remember: true);
        return;
      }
      // Venció o la cerraron desde otro dispositivo.
      _api.sessionCookie = null;
      await _storage.clear();
      yield const SessionGuest(promptLogin: true);
    } on ApiException catch (e) {
      debugPrint('session check: $e');
      yield const SessionGuest(offline: true);
    }
  }
}
