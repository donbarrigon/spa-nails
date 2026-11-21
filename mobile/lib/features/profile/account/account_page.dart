import 'package:client/client.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../../components/app_button.dart';
import '../../../components/info_panel.dart';
import '../../../components/message_banner.dart';
import '../../../components/page_body.dart';
import '../../../core/deps.dart';
import '../profile_form.dart';
import '../widgets/account_labels.dart';
import 'account_dialogs.dart';

/// Correo, teléfono, contraseña y verificación en dos pasos. Cada cambio se
/// hace en un diálogo que pide la contraseña.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) => PageBody(
        children: [
          _EmailPanel(user: user),
          _PhonePanel(user: user),
          InfoPanel(
            title: 'Contraseña',
            icon: Icons.password_outlined,
            footer: [
              _Actions([
                AppButton.outlined(
                  label: 'Cambiar contraseña',
                  expand: false,
                  onPressed: () => showAccountDialog(context, ChangePasswordDialog(email: user.email)),
                ),
              ]),
            ],
          ),
          _TwoFactorPanel(user: user),
          InfoPanel(
            title: 'Google',
            icon: Icons.account_circle_outlined,
            rows: [('Inicio de sesión con Google', AccountLabels.google(user.googleLinked))],
          ),
        ],
      );
}

/// Botones de un panel, alineados a la izquierda y que bajan de línea si no caben.
class _Actions extends StatelessWidget {
  const _Actions(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _EmailPanel extends StatelessWidget {
  const _EmailPanel({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final api = AppDeps.of(context).userApi;

    return ProfileForm(
      successMessage: (result) => switch (result) {
        SessionUser() when user.pendingEmail != null => 'Cancelamos el cambio de correo',
        SessionUser() => 'Tu correo ya está verificado',
        _ => 'Te enviamos un enlace nuevo a ${user.email}',
      },
      builder: (context, state, submit) => InfoPanel(
        title: 'Correo',
        icon: Icons.mail_outline,
        rows: [
          ('Correo', Text(user.email)),
          ('Estado', AccountLabels.verified(user.emailVerified)),
        ],
        footer: [
          if (user.pendingEmail case final pending?)
            MessageBanner(
              'Te enviamos un enlace a $pending. Ábrelo para confirmar el cambio.',
              tone: MessageTone.info,
            ),
          if (state.error case final error?) MessageBanner(error),
          _Actions([
            AppButton.outlined(
              label: 'Cambiar correo',
              expand: false,
              onPressed: state.submitting
                  ? null
                  : () => showAccountDialog(context, ChangeEmailDialog(current: user.email)),
            ),
            if (user.pendingEmail != null)
              AppButton.text(
                label: 'Cancelar cambio',
                loading: state.submitting,
                onPressed: () => submit(api.cancelEmailChange),
              )
            else if (!user.emailVerified)
              AppButton.text(
                label: 'Reenviar verificación',
                loading: state.submitting,
                onPressed: () => submit(() => _resendVerifyEmail(api)),
              ),
          ]),
        ],
      ),
    );
  }
}

/// Reenvía el enlace de verificación. Si el backend responde que ya está
/// verificado (lo verificó desde el enlace y la app no se enteró), devuelve el
/// usuario actualizado para que [ProfileForm] actualice la sesión.
Future<SessionUser?> _resendVerifyEmail(UserApi api) async {
  try {
    await api.resendVerifyEmail();
    return null;
  } on ApiException catch (e) {
    if (e.status != 409) rethrow;
    return api.me();
  }
}

class _PhonePanel extends StatelessWidget {
  const _PhonePanel({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final api = AppDeps.of(context).userApi;
    final pending = user.pendingPhone;

    return ProfileForm(
      successMessage: (result) => result is SessionUser
          ? 'Cancelamos el cambio de teléfono'
          : 'Te enviamos un código nuevo por WhatsApp',
      builder: (context, state, submit) => InfoPanel(
        title: 'Teléfono',
        icon: Icons.phone_outlined,
        rows: [
          ('Teléfono', Text(user.phone)),
          ('Estado', AccountLabels.verified(user.phoneVerified)),
        ],
        footer: [
          if (pending != null)
            MessageBanner(
              'Te enviamos un código por WhatsApp a $pending para confirmar el cambio.',
              tone: MessageTone.info,
            ),
          if (state.error case final error?) MessageBanner(error),
          _Actions([
            if (pending != null) ...[
              AppButton.outlined(
                label: 'Escribir código',
                expand: false,
                onPressed: state.submitting
                    ? null
                    : () => showAccountDialog(context, PhoneCodeDialog.confirmChange(phone: pending)),
              ),
              AppButton.text(
                label: 'Cancelar cambio',
                loading: state.submitting,
                onPressed: () => submit(api.cancelPhoneChange),
              ),
            ] else ...[
              if (!user.phoneVerified) ...[
                AppButton.outlined(
                  label: 'Verificar',
                  expand: false,
                  onPressed: state.submitting
                      ? null
                      : () => showAccountDialog(context, PhoneCodeDialog.verify(phone: user.phone)),
                ),
                AppButton.text(
                  label: 'Reenviar código',
                  loading: state.submitting,
                  onPressed: () => submit(api.resendVerifyPhone),
                ),
              ],
              AppButton.outlined(
                label: 'Cambiar teléfono',
                expand: false,
                onPressed: state.submitting
                    ? null
                    : () => showAccountDialog(context, ChangePhoneDialog(current: user.phone)),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

class _TwoFactorPanel extends StatelessWidget {
  const _TwoFactorPanel({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final totpConfirmed = user.totpConfirmedAt != null;
    final totpInUse = user.twoFactor == TwoFactorMethod.totp;

    return InfoPanel(
      title: 'Verificación en dos pasos',
      icon: Icons.verified_user_outlined,
      rows: [
        ('Método', AccountLabels.twoFactor(user.twoFactor)),
        ('App de autenticación', AccountLabels.totp(totpConfirmed)),
      ],
      footer: [
        Text(
          'Al iniciar sesión te pediremos también un código de 6 dígitos.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        _Actions([
          AppButton.outlined(
            label: user.twoFactor == null ? 'Activar' : 'Cambiar método',
            expand: false,
            onPressed: () => showAccountDialog(context, TwoFactorDialog(user: user)),
          ),
          // Configurar otra app invalida la actual: no si es el método del login.
          if (!totpInUse)
            AppButton.text(
              label: totpConfirmed ? 'Configurar otra app' : 'Configurar app de autenticación',
              onPressed: () => showAccountDialog(context, const TotpSetupDialog()),
            ),
          if (user.twoFactor != null)
            AppButton.text(
              label: 'Desactivar',
              onPressed: () => showAccountDialog(context, const DisableTwoFactorDialog()),
            ),
        ]),
      ],
    );
  }
}
