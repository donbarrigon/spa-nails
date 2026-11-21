import 'package:client/client.dart';
import 'package:shared/shared.dart';

import '../../../core/bloc/bloc.dart';
import 'forgot_password_event.dart';
import 'forgot_password_state.dart';

export 'forgot_password_event.dart';
export 'forgot_password_state.dart';

/// Recuperar contraseña: correo o teléfono → enlace por correo, o código por
/// WhatsApp con la contraseña nueva → listo.
class ForgotPasswordBloc extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  ForgotPasswordBloc({required this._userApi}) : super(const ForgotRequest());

  final UserApi _userApi;

  @override
  Stream<ForgotPasswordState> mapEventToState(ForgotPasswordEvent event) async* {
    switch (event) {
      case ForgotSubmitted(:final user):
        yield* _request(user);
      case ForgotCodeSubmitted(:final code, :final password, :final passwordConfirmation):
        if (state case final ForgotCode step) yield* _reset(step, code, password, passwordConfirmation);
      case ForgotCodeResent():
        if (state case final ForgotCode step) yield* _resend(step);
      case ForgotRestarted():
        yield const ForgotRequest();
    }
  }

  Stream<ForgotPasswordState> _request(String user) async* {
    final form = ForgotPasswordValidator(user: user)..prepareForValidation();
    final errors = form.validate();
    if (errors.isNotEmpty) {
      yield ForgotRequest(fields: errors);
      return;
    }

    yield const ForgotRequest(submitting: true);
    try {
      final method = await _userApi.forgotPassword(form);
      yield method == TwoFactorMethod.whatsapp ? ForgotCode(phone: form.user) : ForgotEmailSent(form.user);
    } on ApiException catch (e) {
      yield ForgotRequest(error: AuthErrors.ofReset(e), fields: e.fields);
    }
  }

  Stream<ForgotPasswordState> _reset(ForgotCode step, String code, String password, String confirmation) async* {
    final form = ResetPasswordCodeValidator(
      phone: step.phone,
      code: code,
      password: password,
      passwordConfirmation: confirmation,
    )..prepareForValidation();
    final errors = form.validate();
    if (errors.isNotEmpty) {
      yield ForgotCode(phone: step.phone, fields: errors);
      return;
    }

    yield ForgotCode(phone: step.phone, submitting: true);
    try {
      await _userApi.resetPasswordCode(form);
      yield const ForgotDone();
    } on ApiException catch (e) {
      yield switch (e.status) {
        404 => ForgotCode(phone: step.phone, fields: const {'code': 'El código no es correcto o ya venció'}),
        _ => ForgotCode(phone: step.phone, error: AuthErrors.ofReset(e), fields: e.fields),
      };
    }
  }

  Stream<ForgotPasswordState> _resend(ForgotCode step) async* {
    yield ForgotCode(phone: step.phone, submitting: true);
    try {
      await _userApi.forgotPassword(ForgotPasswordValidator(user: step.phone));
      yield ForgotCode(phone: step.phone, notice: 'Te enviamos un código nuevo por WhatsApp.');
    } on ApiException catch (e) {
      yield ForgotCode(phone: step.phone, error: AuthErrors.ofReset(e));
    }
  }
}
