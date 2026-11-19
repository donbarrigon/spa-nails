import 'package:client/client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';

import '../../../core/bloc/bloc.dart';
import '../../../core/google_auth.dart';
import 'register_event.dart';
import 'register_state.dart';

export 'register_event.dart';
export 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc({required this._userApi, required this._google}) : super(const RegisterForm());

  final UserApi _userApi;
  final GoogleAuth _google;

  @override
  Stream<RegisterState> mapEventToState(RegisterEvent event) async* {
    switch (event) {
      case RegisterSubmitted(:final form):
        yield* _submit(form, form.remember, () => _userApi.register(form));
      case GoogleRegisterSubmitted(:final form):
        yield* _submit(form, form.remember, () => _googleRegister(form));
    }
  }

  Stream<RegisterState> _submit(
    Validator form,
    bool remember,
    Future<SessionUser> Function() send,
  ) async* {
    form.prepareForValidation();
    final errors = form.validate();
    if (errors.isNotEmpty) {
      yield RegisterForm(fields: errors);
      return;
    }

    yield const RegisterForm(submitting: true);
    try {
      yield RegisterDone(await send(), remember: remember);
    } on ApiException catch (e) {
      final conflict = e.status == 409 ? AuthErrors.registerConflict(e) : const <String, String>{};
      yield RegisterForm(
        error: conflict.isEmpty ? AuthErrors.of(e) : null,
        fields: {...e.fields, ...conflict},
      );
    } on GoogleAuthException catch (e) {
      debugPrint('$e');
      yield const RegisterForm(error: AuthErrors.google);
    }
  }

  /// El ID token de Google dura una hora: si venció mientras llenaba el
  /// formulario (`401`), se pide otro y se reintenta una vez.
  Future<SessionUser> _googleRegister(GoogleRegisterValidator form) async {
    try {
      return await _userApi.googleRegister(form);
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
      final identity = await _google.signIn();
      if (identity == null) rethrow;
      form.idToken = identity.idToken;
      return _userApi.googleRegister(form);
    }
  }
}
