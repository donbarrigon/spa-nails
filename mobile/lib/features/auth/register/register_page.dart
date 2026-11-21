import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../../components/app_button.dart';
import '../../../components/app_text_field.dart';
import '../../../components/message_banner.dart';
import '../../../core/bloc/bloc_provider.dart';
import '../../../core/bloc/bloc_widgets.dart';
import '../../../core/router.dart';
import '../session/session_bloc.dart';
import '../widgets/auth_layout.dart';
import '../widgets/remember_me.dart';
import 'register_bloc.dart';

/// Registro con correo, o completando los datos después de entrar con Google
/// ([google] no nulo: el correo es el de Google y no se pide).
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.google});

  final GoogleRegistration? google;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final _googleEmail = TextEditingController(text: widget.google?.identity.email);
  late bool _remember = widget.google?.remember ?? true;

  RegisterBloc get _bloc => BlocProvider.of<RegisterBloc>(context);

  @override
  void initState() {
    super.initState();
    _name.text = widget.google?.identity.name ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _nickname, _email, _phone, _password, _confirmation, _googleEmail]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final google = widget.google;
    _bloc.add(google == null
        ? RegisterSubmitted(UserRegisterValidator(
            nickname: _nickname.text,
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
            passwordConfirmation: _confirmation.text,
            remember: _remember,
          ))
        : GoogleRegisterSubmitted(GoogleRegisterValidator(
            idToken: google.identity.idToken,
            nickname: _nickname.text,
            name: _name.text,
            phone: _phone.text,
            password: _password.text,
            passwordConfirmation: _confirmation.text,
            remember: _remember,
          )));
  }

  void _onState(BuildContext context, RegisterState state) {
    if (state case RegisterDone(:final user, :final remember)) {
      BlocProvider.of<SessionBloc>(context).add(SessionStarted(user, remember: remember));
      Routes.backToApp(context);
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<RegisterState>(
        bloc: _bloc,
        listener: _onState,
        child: AuthLayout(
          showBack: true,
          child: BlocBuilder<RegisterState>(
            bloc: _bloc,
            builder: (context, state) => _form(switch (state) {
              final RegisterForm form => form,
              RegisterDone() => const RegisterForm(submitting: true),
            }),
          ),
        ),
      );

  Widget _form(RegisterForm state) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final google = widget.google;
    final busy = state.submitting;
    const gap = SizedBox(height: 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Crea tu cuenta', style: text.headlineLarge),
        const SizedBox(height: 6),
        Text(
          google == null
              ? 'Con tu cuenta puedes reservar y ver tus citas.'
              : 'Completa tus datos para terminar de crear tu cuenta con Google.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Nombre completo',
          controller: _name,
          error: state.fields['name'],
          enabled: !busy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
        ),
        gap,
        _LeaveCheck(
          onLeave: () => _bloc.add(RegisterFieldLeft('nickname', _nickname.text)),
          child: AppTextField(
            label: 'Nombre de usuario',
            hint: 'ej. ana.perez',
            controller: _nickname,
            error: state.fields['nickname'],
            enabled: !busy,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],
          ),
        ),
        gap,
        if (google == null) ...[
          _LeaveCheck(
            onLeave: () => _bloc.add(RegisterFieldLeft('email', _email.text)),
            child: AppTextField(
              label: 'Correo',
              controller: _email,
              error: state.fields['email'],
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
          ),
          gap,
        ] else ...[
          AppTextField(
            label: 'Correo de Google',
            controller: _googleEmail,
            readOnly: true,
            enabled: false,
          ),
          gap,
        ],
        _LeaveCheck(
          onLeave: () => _bloc.add(RegisterFieldLeft('phone', _phone.text)),
          child: AppTextField(
            label: 'Teléfono',
            hint: '+57 300 123 4567',
            helper: 'Con el código de país. Te enviaremos un código por WhatsApp para verificarlo.',
            controller: _phone,
            error: state.fields['phone'],
            enabled: !busy,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
        ),
        gap,
        AppTextField(
          label: 'Contraseña',
          helper: 'De 8 a 32 caracteres.',
          controller: _password,
          password: true,
          error: state.fields['password'],
          enabled: !busy,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        gap,
        AppTextField(
          label: 'Repite la contraseña',
          controller: _confirmation,
          password: true,
          error: state.fields['password_confirmation'],
          enabled: !busy,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: RememberMe(
            value: _remember,
            onChanged: busy ? null : (v) => setState(() => _remember = v),
          ),
        ),
        if (state.error case final error?) ...[
          const SizedBox(height: 8),
          MessageBanner(error),
        ],
        const SizedBox(height: 16),
        AppButton(label: 'Crear cuenta', loading: busy, onPressed: _submit),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('¿Ya tienes cuenta?', style: text.bodyMedium),
            AppButton.text(
              label: 'Inicia sesión',
              onPressed: busy ? null : () => Routes.replaceWithLogin(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// Avisa cuando el foco sale del campo de adentro (no en cada tecla).
class _LeaveCheck extends StatelessWidget {
  const _LeaveCheck({required this.onLeave, required this.child});

  final VoidCallback onLeave;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) {
          if (!focused) onLeave();
        },
        child: child,
      );
}
