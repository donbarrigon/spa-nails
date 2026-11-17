import 'package:shared/shared.dart';

import 'api_client.dart';
import 'api_exception.dart';

/// Resultado del primer paso del login (contraseña o Google).
sealed class LoginResult {
  const LoginResult();
}

/// La cuenta no tiene segundo factor: la sesión ya está creada.
final class LoggedIn extends LoginResult {
  const LoggedIn(this.user);
  final SessionUser user;
}

/// La cuenta tiene segundo factor: falta enviar el código con [challenge].
final class TwoFactorRequired extends LoginResult {
  const TwoFactorRequired(this.challenge);
  final TwoFactorChallenge challenge;
}

/// Rutas `/api/users/...` de la cuenta y la sesión.
///
/// Los métodos reciben el validador ya validado: solo envían su `toJson`.
class UserApi {
  UserApi(this._api);

  final ApiClient _api;

  /// `200` con el usuario, o `202` si pide segundo factor.
  Future<LoginResult> login(UserLoginValidator form) async =>
      _loginResult(await _api.post('/api/users/login', form.toJson()));

  /// Igual que [login]. `404` si ese Google no tiene cuenta (debe registrarse) y
  /// `409` si su email ya tiene cuenta (debe entrar con contraseña y vincularlo).
  Future<LoginResult> googleLogin(GoogleLoginValidator form) async =>
      _loginResult(await _api.post('/api/users/login/google', form.toJson()));

  Future<SessionUser> loginTwoFactor(LoginTwoFactorValidator form) async =>
      _user(await _api.post('/api/users/login/two-factor', form.toJson()));

  /// Reenvía el código; con [method] cambia de canal.
  Future<TwoFactorChallenge> resendTwoFactor(String challenge, {TwoFactorMethod? method}) async {
    final res = await _api.post('/api/users/login/two-factor/resend', {
      'challenge': challenge,
      if (method != null) 'method': method.name,
    });
    return TwoFactorChallenge.fromJson(res.json);
  }

  Future<SessionUser> register(UserRegisterValidator form) async =>
      _user(await _api.post('/api/users/register', form.toJson()));

  Future<SessionUser> googleRegister(GoogleRegisterValidator form) async =>
      _user(await _api.post('/api/users/register/google', form.toJson()));

  /// Usuario de la sesión actual, o `null` si no hay sesión o venció.
  Future<SessionUser?> me() async {
    try {
      return _user(await _api.get('/api/users/me'));
    } on ApiException catch (e) {
      if (e.status == 401) return null;
      rethrow;
    }
  }

  Future<void> logout() async {
    await _api.post('/api/users/logout');
  }

  static LoginResult _loginResult(ApiResponse res) => res.status == 202
      ? TwoFactorRequired(TwoFactorChallenge.fromJson(res.json))
      : LoggedIn(SessionUser.fromJson(res.json));

  static SessionUser _user(ApiResponse res) => SessionUser.fromJson(res.json);
}
