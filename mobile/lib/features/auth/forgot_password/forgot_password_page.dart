import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/app_button.dart';
import '../../../components/app_text_field.dart';
import '../../../components/message_banner.dart';
import '../../../core/bloc/bloc_provider.dart';
import '../../../core/bloc/bloc_widgets.dart';
import '../../../core/router.dart';
import '../session/session_bloc.dart';
import '../widgets/auth_layout.dart';
import 'forgot_password_bloc.dart';

/// Recuperar contraseña. Se abre desde el login o desde "Cambiar contraseña"
/// del perfil, con [user] prellenado.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.user});

  final String? user;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final _user = TextEditingController(text: widget.user);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  ForgotPasswordBloc get _bloc => BlocProvider.of<ForgotPasswordBloc>(context);

  @override
  void dispose() {
    _user.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  /// Al cambiar de paso se limpian el código y la contraseña.
  void _onState(BuildContext context, ForgotPasswordState state) {
    if (state is ForgotRequest || state is ForgotDone) {
      _code.clear();
      _password.clear();
      _confirmation.clear();
    }
  }

  /// El backend cerró todas las sesiones, también la de este dispositivo.
  void _toLogin() {
    final session = BlocProvider.of<SessionBloc>(context);
    if (session.state is SessionActive) session.add(const SessionLogoutRequested());
    Routes.replaceWithLogin(context);
  }

  @override
  Widget build(BuildContext context) => BlocListener<ForgotPasswordState>(
    bloc: _bloc,
    listener: _onState,
    child: AuthLayout(
      child: BlocBuilder<ForgotPasswordState>(
        bloc: _bloc,
        builder: (context, state) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (state) {
            ForgotRequest() => _request(state),
            ForgotEmailSent(:final email) => _emailSent(email),
            ForgotCode() => _codeStep(state),
            ForgotDone() => _done(),
          },
        ),
      ),
    ),
  );

  Widget _header(String title, String description, {VoidCallback? onBack}) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(tooltip: 'Volver', icon: const Icon(Icons.arrow_back), onPressed: onBack),
        ),
        const SizedBox(height: 12),
        Text(title, style: text.headlineLarge),
        const SizedBox(height: 6),
        Text(description, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _request(ForgotRequest state) {
    final busy = state.submitting;
    void submit() => _bloc.add(ForgotSubmitted(_user.text));

    return Column(
      key: const ValueKey('request'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          '¿Olvidaste tu contraseña?',
          'Escribe el correo electrónico o el teléfono asociado a tu cuenta y te enviaremos '
              'las instrucciones para crear una contraseña nueva.',
          onBack: busy ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Correo o teléfono',
          hint: 'tu@correo.com o +57 300 123 4567',
          controller: _user,
          error: state.fields['user'],
          enabled: !busy,
          autofocus: widget.user == null,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          onSubmitted: (_) => submit(),
        ),
        if (state.error case final error?) ...[const SizedBox(height: 12), MessageBanner(error)],
        const SizedBox(height: 20),
        AppButton(label: 'Continuar', loading: busy, onPressed: submit),
      ],
    );
  }

  Widget _emailSent(String email) => Column(
    key: const ValueKey('email-sent'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(
        'Revisa tu correo',
        'Si existe una cuenta asociada a $email, te enviamos un enlace para restablecer tu '
            'contraseña. El enlace vence en 60 minutos.',
        onBack: () => _bloc.add(const ForgotRestarted()),
      ),
      const SizedBox(height: 16),
      const MessageBanner(
        'Si no lo recibes en unos minutos, revisa la carpeta de spam o correo no deseado.',
        tone: MessageTone.info,
      ),
      const SizedBox(height: 20),
      AppButton(label: 'Entendido', onPressed: () => Navigator.of(context).pop()),
      const SizedBox(height: 8),
      Center(
        child: AppButton.text(
          label: 'Usar otro correo o teléfono',
          onPressed: () => _bloc.add(const ForgotRestarted()),
        ),
      ),
    ],
  );

  Widget _codeStep(ForgotCode state) {
    final busy = state.submitting;
    void submit() => _bloc.add(
      ForgotCodeSubmitted(code: _code.text, password: _password.text, passwordConfirmation: _confirmation.text),
    );

    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          'Crea una contraseña nueva',
          'Si existe una cuenta asociada a ${state.phone}, te enviamos un código de 6 dígitos '
              'por WhatsApp. Escríbelo junto con tu nueva contraseña.',
          onBack: busy ? null : () => _bloc.add(const ForgotRestarted()),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Código',
          controller: _code,
          error: state.fields['code'],
          enabled: !busy,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Contraseña nueva',
          helper: 'De 8 a 32 caracteres.',
          controller: _password,
          password: true,
          error: state.fields['password'],
          enabled: !busy,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Repite la contraseña nueva',
          controller: _confirmation,
          password: true,
          error: state.fields['password_confirmation'],
          enabled: !busy,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => submit(),
        ),
        if (state.error case final error?) ...[const SizedBox(height: 12), MessageBanner(error)],
        if (state.notice case final notice?) ...[
          const SizedBox(height: 12),
          MessageBanner(notice, tone: MessageTone.info),
        ],
        const SizedBox(height: 20),
        AppButton(label: 'Cambiar contraseña', loading: busy, onPressed: submit),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            AppButton.text(
              label: 'Reenviar código',
              onPressed: busy ? null : () => _bloc.add(const ForgotCodeResent()),
            ),
            AppButton.text(
              label: 'Usar otro correo o teléfono',
              onPressed: busy ? null : () => _bloc.add(const ForgotRestarted()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _done() {
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Contraseña actualizada', style: text.headlineLarge),
        const SizedBox(height: 6),
        Text(
          'Tu contraseña se cambió correctamente. Por seguridad, cerramos tu sesión en todos los '
          'dispositivos. Inicia sesión con tu nueva contraseña.',
          style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        AppButton(label: 'Iniciar sesión', onPressed: _toLogin),
      ],
    );
  }
}
