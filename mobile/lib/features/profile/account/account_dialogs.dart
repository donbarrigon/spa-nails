import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared/shared.dart';

import '../../../components/app_text_field.dart';
import '../../../core/deps.dart';
import '../profile_form.dart';
import '../widgets/account_labels.dart';
import '../widgets/form_dialog.dart';

Future<void> showAccountDialog(BuildContext context, Widget dialog) =>
    showDialog<void>(context: context, builder: (_) => dialog);

/// Formulario de un diálogo: se cierra al terminar bien.
mixin _DialogForm<T extends StatefulWidget> on State<T> {
  /// Controladores que se liberan al cerrar.
  List<TextEditingController> get controllers;

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void close(Object? _) => Navigator.of(context).pop();
}

// ===============================================================================
// Correo y teléfono
// ===============================================================================

class ChangeEmailDialog extends StatefulWidget {
  const ChangeEmailDialog({super.key, required this.current});

  final String current;

  @override
  State<ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<ChangeEmailDialog> with _DialogForm {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  List<TextEditingController> get controllers => [_email, _password];

  @override
  Widget build(BuildContext context) => ProfileForm(
        successMessage: (_) => 'Revisa tu correo nuevo para confirmar el cambio',
        onDone: close,
        builder: (context, state, submit) {
          void send() {
            final form = ChangeEmailValidator(email: _email.text, password: _password.text);
            final api = AppDeps.of(context).userApi;
            submit(() => api.changeEmail(form), form: form);
          }

          return FormDialog(
            title: 'Cambiar correo',
            description: 'Tu correo actual es ${widget.current}. Te enviaremos un enlace al '
                'correo nuevo; el cambio se hace cuando lo abras.',
            state: state,
            submitLabel: 'Enviar enlace',
            onSubmit: send,
            children: [
              AppTextField(
                label: 'Correo nuevo',
                controller: _email,
                error: state.fields['email'],
                enabled: !state.submitting,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
              ),
              _PasswordField(controller: _password, state: state, onSubmitted: send),
            ],
          );
        },
      );
}

class ChangePhoneDialog extends StatefulWidget {
  const ChangePhoneDialog({super.key, required this.current});

  final String current;

  @override
  State<ChangePhoneDialog> createState() => _ChangePhoneDialogState();
}

class _ChangePhoneDialogState extends State<ChangePhoneDialog> with _DialogForm {
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  List<TextEditingController> get controllers => [_phone, _password];

  @override
  Widget build(BuildContext context) => ProfileForm(
        successMessage: (_) => 'Te enviamos un código por WhatsApp al teléfono nuevo',
        onDone: close,
        builder: (context, state, submit) {
          void send() {
            final form = ChangePhoneValidator(phone: _phone.text, password: _password.text);
            final api = AppDeps.of(context).userApi;
            submit(() => api.changePhone(form), form: form);
          }

          return FormDialog(
            title: 'Cambiar teléfono',
            description: 'Tu teléfono actual es ${widget.current}. Te enviaremos un código por '
                'WhatsApp al teléfono nuevo para confirmarlo.',
            state: state,
            submitLabel: 'Enviar código',
            onSubmit: send,
            children: [
              AppTextField(
                label: 'Teléfono nuevo',
                hint: '+57 300 123 4567',
                helper: 'Con el código de país.',
                controller: _phone,
                error: state.fields['phone'],
                enabled: !state.submitting,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
              ),
              _PasswordField(controller: _password, state: state, onSubmitted: send),
            ],
          );
        },
      );
}

/// Código de WhatsApp para verificar el teléfono actual o confirmar el nuevo.
class PhoneCodeDialog extends StatefulWidget {
  const PhoneCodeDialog.verify({super.key, required this.phone}) : _confirmChange = false;

  const PhoneCodeDialog.confirmChange({super.key, required this.phone}) : _confirmChange = true;

  final String phone;
  final bool _confirmChange;

  @override
  State<PhoneCodeDialog> createState() => _PhoneCodeDialogState();
}

class _PhoneCodeDialogState extends State<PhoneCodeDialog> with _DialogForm {
  final _code = TextEditingController();

  @override
  List<TextEditingController> get controllers => [_code];

  @override
  Widget build(BuildContext context) => ProfileForm(
        successMessage: (_) => widget._confirmChange ? 'Cambiamos tu teléfono' : 'Verificamos tu teléfono',
        onDone: close,
        builder: (context, state, submit) {
          void send() {
            final form = CodeValidator(code: _code.text);
            final api = AppDeps.of(context).userApi;
            submit(
              () => widget._confirmChange ? api.confirmPhoneChange(form) : api.verifyPhone(form),
              form: form,
            );
          }

          return FormDialog(
            title: widget._confirmChange ? 'Confirmar teléfono nuevo' : 'Verificar teléfono',
            description: 'Escribe el código de 6 dígitos que te enviamos por WhatsApp a ${widget.phone}.',
            state: state,
            submitLabel: 'Confirmar',
            onSubmit: send,
            children: [_CodeField(controller: _code, state: state, onSubmitted: send)],
          );
        },
      );
}

// ===============================================================================
// Contraseña
// ===============================================================================

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> with _DialogForm {
  final _current = TextEditingController();
  final _password = TextEditingController();

  @override
  List<TextEditingController> get controllers => [_current, _password];

  @override
  Widget build(BuildContext context) => ProfileForm(
        successMessage: (_) => 'Cambiamos tu contraseña y cerramos tus otras sesiones',
        onDone: close,
        builder: (context, state, submit) {
          void send() {
            final form = ChangePasswordValidator(currentPassword: _current.text, password: _password.text);
            final api = AppDeps.of(context).userApi;
            submit(() => api.changePassword(form), form: form);
          }

          return FormDialog(
            title: 'Cambiar contraseña',
            description: 'Cerraremos tu sesión en los demás dispositivos; en este sigue abierta.',
            state: state,
            submitLabel: 'Cambiar',
            onSubmit: send,
            children: [
              AppTextField(
                label: 'Contraseña actual',
                controller: _current,
                password: true,
                error: state.fields['current_password'],
                enabled: !state.submitting,
                autofocus: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
              ),
              AppTextField(
                label: 'Contraseña nueva',
                helper: 'De 8 a 32 caracteres.',
                controller: _password,
                password: true,
                error: state.fields['password'],
                enabled: !state.submitting,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => send(),
              ),
            ],
          );
        },
      );
}

// ===============================================================================
// Verificación en dos pasos
// ===============================================================================

/// Activa la verificación en dos pasos o cambia su método. Solo se ofrecen los
/// canales verificados y la app ya configurada.
class TwoFactorDialog extends StatefulWidget {
  const TwoFactorDialog({super.key, required this.user});

  final SessionUser user;

  @override
  State<TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<TwoFactorDialog> with _DialogForm {
  final _password = TextEditingController();
  late TwoFactorMethod? _method = widget.user.twoFactor ?? _available.firstOrNull;

  @override
  List<TextEditingController> get controllers => [_password];

  Iterable<TwoFactorMethod> get _available => TwoFactorMethod.values.where(_canUse);

  bool _canUse(TwoFactorMethod method) => switch (method) {
        TwoFactorMethod.email => widget.user.emailVerified,
        TwoFactorMethod.whatsapp => widget.user.phoneVerified,
        TwoFactorMethod.totp => widget.user.totpConfirmedAt != null,
      };

  String _hint(TwoFactorMethod method) => switch (method) {
        TwoFactorMethod.email => _canUse(method) ? widget.user.email : 'Primero verifica tu correo',
        TwoFactorMethod.whatsapp => _canUse(method) ? widget.user.phone : 'Primero verifica tu teléfono',
        TwoFactorMethod.totp =>
          _canUse(method) ? 'Google Authenticator, Authy...' : 'Primero configura la app',
      };

  @override
  Widget build(BuildContext context) => ProfileForm(
        successMessage: (_) => 'Guardamos tu verificación en dos pasos',
        onDone: close,
        builder: (context, state, submit) {
          final busy = state.submitting;

          void send() {
            final method = _method;
            if (method == null) return;
            final form = TwoFactorValidator(method: method, password: _password.text);
            final api = AppDeps.of(context).userApi;
            submit(() => api.updateTwoFactor(form), form: form);
          }

          return FormDialog(
            title: 'Verificación en dos pasos',
            description: '¿Cómo quieres recibir el código al iniciar sesión?',
            state: state,
            submitLabel: 'Guardar',
            onSubmit: _method == null ? null : send,
            children: [
              RadioGroup<TwoFactorMethod>(
                groupValue: _method,
                onChanged: (m) => setState(() => _method = m),
                child: Column(
                  children: [
                    for (final method in TwoFactorMethod.values)
                      RadioListTile<TwoFactorMethod>(
                        value: method,
                        enabled: !busy && _canUse(method),
                        contentPadding: EdgeInsets.zero,
                        title: Text(AccountLabels.method(method)),
                        subtitle: Text(_hint(method)),
                      ),
                  ],
                ),
              ),
              _PasswordField(controller: _password, state: state, onSubmitted: send),
            ],
          );
        },
      );
}

class DisableTwoFactorDialog extends StatefulWidget {
  const DisableTwoFactorDialog({super.key});

  @override
  State<DisableTwoFactorDialog> createState() => _DisableTwoFactorDialogState();
}

class _DisableTwoFactorDialogState extends State<DisableTwoFactorDialog> with _DialogForm {
  final _password = TextEditingController();

  @override
  List<TextEditingController> get controllers => [_password];

  @override
  Widget build(BuildContext context) => ProfileForm(
        successMessage: (_) => 'Desactivamos la verificación en dos pasos',
        onDone: close,
        builder: (context, state, submit) {
          void send() {
            final form = PasswordValidator(password: _password.text);
            final api = AppDeps.of(context).userApi;
            submit(() => api.disableTwoFactor(form), form: form);
          }

          return FormDialog(
            title: 'Desactivar verificación en dos pasos',
            description: 'Solo te pediremos la contraseña al iniciar sesión. También se '
                'borra la app de autenticación: para volver a usarla tendrás que configurarla.',
            state: state,
            submitLabel: 'Desactivar',
            onSubmit: send,
            children: [_PasswordField(controller: _password, state: state, onSubmitted: send, autofocus: true)],
          );
        },
      );
}

/// Dos pasos: la contraseña genera el secreto, y el primer código de la app lo confirma.
class TotpSetupDialog extends StatefulWidget {
  const TotpSetupDialog({super.key});

  @override
  State<TotpSetupDialog> createState() => _TotpSetupDialogState();
}

class _TotpSetupDialogState extends State<TotpSetupDialog> with _DialogForm {
  final _password = TextEditingController();
  final _code = TextEditingController();
  TotpSetup? _setup;

  @override
  List<TextEditingController> get controllers => [_password, _code];

  void _onDone(Object? result) {
    if (result case final TotpSetup setup) {
      setState(() => _setup = setup);
    } else {
      close(result);
    }
  }

  @override
  Widget build(BuildContext context) => ProfileForm(
        successMessage: (result) => result is SessionUser ? 'Configuraste la app de autenticación' : null,
        onDone: _onDone,
        builder: (context, state, submit) {
          final api = AppDeps.of(context).userApi;

          if (_setup case final setup?) {
            void confirm() {
              final form = CodeValidator(code: _code.text);
              submit(() => api.confirmTotp(form), form: form);
            }

            return FormDialog(
              title: 'Escanea el código',
              description: 'Abre tu app de autenticación, escanea este código y escribe '
                  'los 6 dígitos que te muestra.',
              state: state,
              submitLabel: 'Confirmar',
              onSubmit: confirm,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(setup.qr),
                      width: 200,
                      height: 200,
                      filterQuality: FilterQuality.none,
                      semanticLabel: 'Código QR para la app de autenticación',
                    ),
                  ),
                ),
                _SecretKey(secret: setup.secret),
                _CodeField(controller: _code, state: state, onSubmitted: confirm),
              ],
            );
          }

          void start() {
            final form = PasswordValidator(password: _password.text);
            submit(() => api.setupTotp(form), form: form);
          }

          return FormDialog(
            title: 'App de autenticación',
            description: 'Usa una app como Google Authenticator o Authy para generar los códigos. '
                'Si ya tenías una configurada, dejará de servir.',
            state: state,
            submitLabel: 'Continuar',
            onSubmit: start,
            children: [_PasswordField(controller: _password, state: state, onSubmitted: start, autofocus: true)],
          );
        },
      );
}

/// La clave para escribirla a mano si no puede escanear el QR.
class _SecretKey extends StatelessWidget {
  const _SecretKey({required this.secret});

  final String secret;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('O escribe esta clave', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                SelectableText(secret, style: text.bodyMedium?.copyWith(letterSpacing: 1.2)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar clave',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: secret));
              if (context.mounted) {
                ScaffoldMessenger.maybeOf(context)
                    ?.showSnackBar(const SnackBar(content: Text('Copiamos la clave')));
              }
            },
          ),
        ],
      ),
    );
  }
}

// ===============================================================================
// Campos
// ===============================================================================

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.state,
    required this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ProfileFormIdle state;
  final VoidCallback onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => AppTextField(
        label: 'Tu contraseña',
        controller: controller,
        password: true,
        error: state.fields['password'],
        enabled: !state.submitting,
        autofocus: autofocus,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => onSubmitted(),
      );
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.state, required this.onSubmitted});

  final TextEditingController controller;
  final ProfileFormIdle state;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => AppTextField(
        label: 'Código',
        hint: '123456',
        controller: controller,
        error: state.fields['code'],
        enabled: !state.submitting,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.oneTimeCode],
        onSubmitted: (_) => onSubmitted(),
      );
}
