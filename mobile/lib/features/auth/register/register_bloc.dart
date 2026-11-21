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

  /// Lo que ya es de otra cuenta: campo → valor normalizado.
  final _taken = <String, String>{};

  /// Último valor revisado de cada campo: si no cambió no se vuelve a preguntar.
  final _checked = <String, String>{};

  @override
  Stream<RegisterState> mapEventToState(RegisterEvent event) async* {
    switch (event) {
      case RegisterSubmitted(:final form):
        yield* _submit(form, form.remember, () => _userApi.register(form));
      case GoogleRegisterSubmitted(:final form):
        yield* _submit(form, form.remember, () => _googleRegister(form));
      case RegisterFieldLeft(:final field, :final value):
        yield* _check(field, value);
    }
  }

  static String _normalized(String field, String value) =>
      (RegisterAvailableValidator(field: field, value: value)..prepareForValidation()).value;

  Stream<RegisterState> _check(String field, String value) async* {
    final form = RegisterAvailableValidator(field: field, value: value)..prepareForValidation();

    // Cambió lo que estaba en uso: ese error ya no aplica.
    if (_taken.containsKey(field) && _taken[field] != form.value) {
      _taken.remove(field);
      yield* _setField(field, null);
    }
    // Con formato inválido no se pregunta: el registro lo explica al enviarlo.
    if (form.validate().isNotEmpty || _checked[field] == form.value) return;

    _checked[field] = form.value;
    try {
      if (await _userApi.registerAvailable(form)) {
        yield* _setField(field, null);
      } else {
        _taken[field] = form.value;
        yield* _setField(field, AuthErrors.registerTaken[field]);
      }
    } on ApiException catch (e) {
      // Sin conexión o demasiadas peticiones: se revisa de nuevo al enviar.
      debugPrint('register available: $e');
      _checked.remove(field);
    }
  }

  /// Cambia solo el error de [field], si el formulario no se está enviando.
  Stream<RegisterState> _setField(String field, String? fieldError) async* {
    if (state case RegisterForm(submitting: false, :final error, :final fields)) {
      final next = {...fields}..remove(field);
      if (fieldError != null) next[field] = fieldError;
      yield RegisterForm(error: error, fields: next);
    }
  }

  Stream<RegisterState> _submit(
    Validator form,
    bool remember,
    Future<SessionUser> Function() send,
  ) async* {
    form.prepareForValidation();
    final errors = {..._stillTaken(form.toJson()), ...form.validate()};
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

  /// Los "ya está en uso" que siguen valiendo para lo que está escrito ahora.
  Map<String, String> _stillTaken(Map<String, Object?> json) => {
        for (final MapEntry(key: field, :value) in _taken.entries)
          if (_normalized(field, '${json[field] ?? ''}') == value) field: AuthErrors.registerTaken[field]!,
      };

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
