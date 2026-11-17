import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../../components/app_button.dart';
import '../../../components/app_text_field.dart';
import '../../../components/brand_mark.dart';
import '../../../components/message_banner.dart';
import '../../../core/bloc/bloc_provider.dart';
import '../../../core/bloc/bloc_widgets.dart';
import '../../../core/deps.dart';
import '../../../core/router.dart';
import '../register/register_event.dart';
import '../session/session_bloc.dart';
import '../widgets/auth_layout.dart';
import '../widgets/remember_me.dart';
import 'login_bloc.dart';
import 'two_factor_step.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;

  LoginBloc get _bloc => BlocProvider.of<LoginBloc>(context);

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => _bloc.add(LoginSubmitted(
        UserLoginValidator(user: _user.text, password: _password.text, remember: _remember),
      ));

  void _onState(BuildContext context, LoginState state) {
    switch (state) {
      case LoginDone(:final user, :final remember):
        BlocProvider.of<SessionBloc>(context).add(SessionStarted(user, remember: remember));
        Routes.backToApp(context);
      case LoginNeedsGoogleRegistration(:final identity, :final remember):
        Routes.replaceWithRegister(
          context,
          google: GoogleRegistration(identity: identity, remember: remember),
        );
      case LoginCredentials() || LoginTwoFactor():
        break;
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<LoginState>(
        bloc: _bloc,
        listener: _onState,
        child: AuthLayout(
          child: BlocBuilder<LoginState>(
            bloc: _bloc,
            builder: (context, state) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (state) {
                LoginTwoFactor() => TwoFactorStep(key: const ValueKey('two-factor'), state: state),
                LoginCredentials() => _credentials(state),
                // Mientras navega, deja el formulario quieto.
                LoginDone() || LoginNeedsGoogleRegistration() =>
                  _credentials(const LoginCredentials(submitting: true)),
              },
            ),
          ),
        ),
      );

  Widget _credentials(LoginCredentials state) {
    final text = Theme.of(context).textTheme;
    final google = AppDeps.of(context).google;
    final busy = state.submitting;

    return Column(
      key: const ValueKey('credentials'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 36)),
        const SizedBox(height: 28),
        Text('Hola de nuevo', style: text.headlineLarge),
        const SizedBox(height: 6),
        Text(
          'Inicia sesión para reservar y ver tus citas.',
          style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Correo o teléfono',
          hint: 'tu@correo.com o +57 300 123 4567',
          controller: _user,
          error: state.fields['user'],
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Contraseña',
          controller: _password,
          password: true,
          error: state.fields['password'],
          enabled: !busy,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
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
        AppButton(label: 'Iniciar sesión', loading: busy, onPressed: _submit),
        if (google.isAvailable) ...[
          const SizedBox(height: 16),
          const _OrDivider(),
          const SizedBox(height: 16),
          AppButton.outlined(
            label: 'Continuar con Google',
            onPressed: busy ? null : () => _bloc.add(LoginWithGoogle(remember: _remember)),
          ),
        ],
        const SizedBox(height: 8),
        if (Navigator.of(context).canPop())
          Center(
            child: AppButton.text(
              label: 'Ahora no',
              onPressed: busy ? null : () => Navigator.of(context).pop(),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('¿No tienes cuenta?', style: text.bodyMedium),
            AppButton.text(
              label: 'Crear cuenta',
              onPressed: busy ? null : () => Routes.replaceWithRegister(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
        spacing: 12,
        children: [
          const Expanded(child: Divider()),
          Text('o', style: Theme.of(context).textTheme.bodySmall),
          const Expanded(child: Divider()),
        ],
      );
}
