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

/// Rutas `/api/users/auth/...` de la cuenta y la sesión.
///
/// Los métodos reciben el validador ya validado: solo envían su `toJson`.
class UserApi {
  UserApi(this._api);

  final ApiClient _api;

  /// `200` con el usuario, o `202` si pide segundo factor.
  Future<LoginResult> login(UserLoginValidator form) async =>
      _loginResult(await _api.post('/api/users/auth/login', form.toJson()));

  /// Igual que [login]. `404` si ese Google no tiene cuenta (debe registrarse) y
  /// `409` si su email ya tiene cuenta (debe entrar con contraseña y vincularlo).
  Future<LoginResult> googleLogin(GoogleLoginValidator form) async =>
      _loginResult(await _api.post('/api/users/auth/login/google', form.toJson()));

  Future<SessionUser> loginTwoFactor(LoginTwoFactorValidator form) async =>
      _user(await _api.post('/api/users/auth/login/two-factor', form.toJson()));

  /// Reenvía el código; con [method] cambia de canal.
  Future<TwoFactorChallenge> resendTwoFactor(String challenge, {TwoFactorMethod? method}) async {
    final res = await _api.post('/api/users/auth/login/two-factor/resend', {
      'challenge': challenge,
      if (method != null) 'method': method.name,
    });
    return TwoFactorChallenge.fromJson(res.json);
  }

  Future<SessionUser> register(UserRegisterValidator form) async =>
      _user(await _api.post('/api/users/auth/register', form.toJson()));

  /// `true` si el dato del registro está libre, `false` si ya es de otra cuenta (`409`).
  Future<bool> registerAvailable(RegisterAvailableValidator form) async {
    try {
      await _api.post('/api/users/auth/register/available', form.toJson());
      return true;
    } on ApiException catch (e) {
      if (e.status == 409) return false;
      rethrow;
    }
  }

  Future<SessionUser> googleRegister(GoogleRegisterValidator form) async =>
      _user(await _api.post('/api/users/auth/register/google', form.toJson()));

  /// Usuario de la sesión actual, o `null` si no hay sesión o venció.
  Future<SessionUser?> me() async {
    try {
      return _user(await _api.get('/api/users/auth/me'));
    } on ApiException catch (e) {
      if (e.status == 401) return null;
      rethrow;
    }
  }

  Future<void> logout() async {
    await _api.post('/api/users/auth/logout');
  }

  // == Recuperar contraseña (sin sesión) =====================================

  /// Envía el enlace (email) o el código (WhatsApp) y responde por dónde, exista
  /// o no la cuenta. `429` si pidió demasiados.
  Future<TwoFactorMethod> forgotPassword(ForgotPasswordValidator form) async {
    final res = await _api.post('/api/users/auth/password/forgot', form.toJson());
    return TwoFactorMethod.tryParse(res.json['method']) ?? TwoFactorMethod.email;
  }

  /// Con el código de WhatsApp. Cierra todas las sesiones, también la actual.
  /// `404` si el código no es correcto o venció; `410` si el teléfono cambió.
  Future<void> resetPasswordCode(ResetPasswordCodeValidator form) async {
    await _api.post('/api/users/auth/password/reset/code', form.toJson());
  }

  // == Cuenta (con sesión) ====================================================
  // Las que cambian algo responden el usuario actualizado. `403` si la
  // contraseña no es correcta.

  /// El correo nuevo queda en `pendingEmail` hasta que abra el enlace que le llega.
  /// `409` si ya es de otra cuenta.
  Future<SessionUser> changeEmail(ChangeEmailValidator form) async =>
      _user(await _api.put('/api/users/auth/email', form.toJson()));

  Future<SessionUser> cancelEmailChange() async =>
      _user(await _api.delete('/api/users/auth/email/pending'));

  Future<void> resendVerifyEmail() async {
    await _api.post('/api/users/auth/verify/email/resend');
  }

  /// El teléfono nuevo queda en `pendingPhone` hasta [confirmPhoneChange].
  /// `409` si ya es de otra cuenta.
  Future<SessionUser> changePhone(ChangePhoneValidator form) async =>
      _user(await _api.put('/api/users/auth/phone', form.toJson()));

  /// Con el código que llegó al teléfono nuevo.
  Future<SessionUser> confirmPhoneChange(CodeValidator form) async =>
      _user(await _api.post('/api/users/auth/phone/confirm', form.toJson()));

  Future<SessionUser> cancelPhoneChange() async =>
      _user(await _api.delete('/api/users/auth/phone/pending'));

  /// Con el código que llegó por WhatsApp al teléfono actual.
  Future<SessionUser> verifyPhone(CodeValidator form) async =>
      _user(await _api.post('/api/users/auth/verify/phone', form.toJson()));

  Future<void> resendVerifyPhone() async {
    await _api.post('/api/users/auth/verify/phone/resend');
  }

  /// Cierra las demás sesiones; la actual sigue abierta.
  Future<void> changePassword(ChangePasswordValidator form) async {
    await _api.put('/api/users/auth/password', form.toJson());
  }

  /// `422` si el método no está verificado o la app no está confirmada.
  Future<SessionUser> updateTwoFactor(TwoFactorValidator form) async =>
      _user(await _api.put('/api/users/auth/two-factor', form.toJson()));

  /// También borra la app de autenticación.
  Future<SessionUser> disableTwoFactor(PasswordValidator form) async =>
      _user(await _api.delete('/api/users/auth/two-factor', form.toJson()));

  /// Secreto nuevo para la app; sirve después de [confirmTotp].
  /// `409` si la app es el método actual.
  Future<TotpSetup> setupTotp(PasswordValidator form) async =>
      TotpSetup.fromJson((await _api.post('/api/users/auth/totp', form.toJson())).json);

  Future<SessionUser> confirmTotp(CodeValidator form) async =>
      _user(await _api.post('/api/users/auth/totp/confirm', form.toJson()));

  static LoginResult _loginResult(ApiResponse res) => res.status == 202
      ? TwoFactorRequired(TwoFactorChallenge.fromJson(res.json))
      : LoggedIn(SessionUser.fromJson(res.json));

  static SessionUser _user(ApiResponse res) => SessionUser.fromJson(res.json);
}
