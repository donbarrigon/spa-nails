import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared/shared.dart';

import '../../../components/app_button.dart';
import '../../../components/app_text_field.dart';
import '../../../components/message_banner.dart';
import '../../../core/bloc/bloc_provider.dart';
import 'login_bloc.dart';

/// Paso 2 del login: el código de 6 dígitos del segundo factor.
class TwoFactorStep extends StatefulWidget {
  const TwoFactorStep({super.key, required this.state});

  final LoginTwoFactor state;

  @override
  State<TwoFactorStep> createState() => _TwoFactorStepState();
}

class _TwoFactorStepState extends State<TwoFactorStep> {
  final _code = TextEditingController();

  LoginBloc get _bloc => BlocProvider.of<LoginBloc>(context);

  @override
  void didUpdateWidget(TwoFactorStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Con un código nuevo (otro challenge) el anterior ya no sirve.
    if (oldWidget.state.challenge.challenge != widget.state.challenge.challenge) _code.clear();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() => _bloc.add(TwoFactorSubmitted(_code.text));

  static String _where(TwoFactorMethod method) => switch (method) {
        TwoFactorMethod.email => 'Te enviamos un código de 6 dígitos a tu correo.',
        TwoFactorMethod.whatsapp => 'Te enviamos un código de 6 dígitos por WhatsApp.',
        TwoFactorMethod.totp => 'Escribe el código de 6 dígitos de tu app de autenticación.',
      };

  static String _switchLabel(TwoFactorMethod method) => switch (method) {
        TwoFactorMethod.email => 'Enviar al correo',
        TwoFactorMethod.whatsapp => 'Enviar por WhatsApp',
        TwoFactorMethod.totp => 'Usar app de autenticación',
      };

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final method = state.challenge.method;
    final busy = state.submitting;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back),
            onPressed: busy ? null : () => _bloc.add(const TwoFactorCancelled()),
          ),
        ),
        const SizedBox(height: 12),
        Text('Verifica que eres tú', style: text.headlineLarge),
        const SizedBox(height: 6),
        Text(_where(method), style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Código',
          controller: _code,
          error: state.codeError,
          enabled: !busy,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          onSubmitted: (_) => _submit(),
        ),
        if (state.error case final error?) ...[
          const SizedBox(height: 12),
          MessageBanner(error),
        ],
        if (state.notice case final notice?) ...[
          const SizedBox(height: 12),
          MessageBanner(notice, tone: MessageTone.info),
        ],
        const SizedBox(height: 20),
        AppButton(label: 'Verificar', loading: busy, onPressed: _submit),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            if (method != TwoFactorMethod.totp)
              AppButton.text(
                label: 'Reenviar código',
                onPressed: busy ? null : () => _bloc.add(const TwoFactorResent()),
              ),
            for (final other in TwoFactorMethod.values.where((m) => m != method))
              AppButton.text(
                label: _switchLabel(other),
                onPressed: busy ? null : () => _bloc.add(TwoFactorResent(other)),
              ),
          ],
        ),
      ],
    );
  }
}
