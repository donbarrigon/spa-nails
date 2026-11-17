import 'package:client/client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';

import '../../../core/bloc/bloc.dart';
import '../../../core/google_auth.dart';
import '../auth_errors.dart';
import 'login_event.dart';
import 'login_state.dart';

export 'login_event.dart';
export 'login_state.dart';

/// Flujo del login: credenciales o Google → segundo factor si la cuenta lo
/// tiene → sesión. Vive mientras está abierta la pantalla de login.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({required this._userApi, required this._google}) : super(const LoginCredentials());

  final UserApi _userApi;
  final GoogleAuth _google;

  @override
  Stream<LoginState> mapEventToState(LoginEvent event) async* {
    switch (event) {
      case LoginSubmitted(:final form):
        yield* _login(form);
      case LoginWithGoogle(:final remember):
        yield* _loginWithGoogle(remember);
      case TwoFactorSubmitted(:final code):
        if (state case final LoginTwoFactor step) yield* _submitCode(step, code);
      case TwoFactorResent(:final method):
        if (state case final LoginTwoFactor step) yield* _resend(step, method);
      case TwoFactorCancelled():
        yield const LoginCredentials();
    }
  }

  Stream<LoginState> _login(UserLoginValidator form) async* {
    form.prepareForValidation();
    final errors = form.validate();
    if (errors.isNotEmpty) {
      yield LoginCredentials(fields: errors);
      return;
    }

    yield const LoginCredentials(submitting: true);
    try {
      yield _afterFirstStep(await _userApi.login(form), form.remember);
    } on ApiException catch (e) {
      yield LoginCredentials(error: AuthErrors.of(e), fields: e.fields);
    }
  }

  Stream<LoginState> _loginWithGoogle(bool remember) async* {
    yield const LoginCredentials(submitting: true);

    final GoogleIdentity? identity;
    try {
      identity = await _google.signIn();
    } on GoogleAuthException catch (e) {
      debugPrint('$e');
      yield const LoginCredentials(error: AuthErrors.google);
      return;
    }
    if (identity == null) {
      // Canceló el selector de cuentas.
      yield const LoginCredentials();
      return;
    }

    try {
      final form = GoogleLoginValidator(idToken: identity.idToken, remember: remember);
      yield _afterFirstStep(await _userApi.googleLogin(form), remember);
    } on ApiException catch (e) {
      yield switch (e.status) {
        404 => LoginNeedsGoogleRegistration(identity, remember: remember),
        409 => const LoginCredentials(error: AuthErrors.googleAccountExists),
        401 => const LoginCredentials(error: AuthErrors.google),
        _ => LoginCredentials(error: AuthErrors.of(e)),
      };
    }
  }

  LoginState _afterFirstStep(LoginResult result, bool remember) => switch (result) {
        LoggedIn(:final user) => LoginDone(user, remember: remember),
        TwoFactorRequired(:final challenge) => LoginTwoFactor(challenge: challenge, remember: remember),
      };

  Stream<LoginState> _submitCode(LoginTwoFactor step, String code) async* {
    final form = LoginTwoFactorValidator(challenge: step.challenge.challenge, code: code)
      ..prepareForValidation();
    if (form.validate()['code'] case final error?) {
      yield step.copyWith(codeError: error);
      return;
    }

    yield step.copyWith(submitting: true);
    try {
      final user = await _userApi.loginTwoFactor(form);
      yield LoginDone(user, remember: step.remember);
    } on ApiException catch (e) {
      yield switch (e.status) {
        // El challenge venció o se gastó: hay que repetir el primer paso.
        401 => const LoginCredentials(error: AuthErrors.signInExpired),
        404 => step.copyWith(codeError: AuthErrors.ofCode(e)),
        _ => step.copyWith(error: AuthErrors.ofCode(e)),
      };
    }
  }

  Stream<LoginState> _resend(LoginTwoFactor step, TwoFactorMethod? method) async* {
    yield step.copyWith(submitting: true);
    try {
      final challenge = await _userApi.resendTwoFactor(step.challenge.challenge, method: method);
      yield step.copyWith(
        challenge: challenge,
        notice: challenge.method == TwoFactorMethod.totp
            ? 'Escribe el código que muestra tu app de autenticación.'
            : 'Te enviamos un código nuevo.',
      );
    } on ApiException catch (e) {
      yield switch (e.status) {
        401 => const LoginCredentials(error: AuthErrors.signInExpired),
        429 => const LoginCredentials(
            error: 'Pediste demasiados códigos. Vuelve a ingresar tus datos.',
          ),
        _ => step.copyWith(error: AuthErrors.ofCode(e)),
      };
    }
  }
}
