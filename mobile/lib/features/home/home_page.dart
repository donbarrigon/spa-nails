import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../components/app_button.dart';
import '../../components/app_top_bar.dart';
import '../../components/message_banner.dart';
import '../../components/page_body.dart';
import '../../components/status_chip.dart';
import '../../core/bloc/bloc_provider.dart';
import '../../core/bloc/bloc_widgets.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/router.dart';
import '../auth/session/session_bloc.dart';

/// Inicio. Por ahora muestra los datos de la sesión, o invita a entrar.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = BlocProvider.of<SessionBloc>(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const AppTopBar(title: 'Inicio', showMenu: true),
      body: BlocBuilder<SessionState>(
        bloc: session,
        builder: (context, state) => PageBody(
          children: [
            Text(
              switch (state) {
                SessionActive(:final user) => 'Hola, ${user.name.split(' ').first}',
                _ => 'Te damos la bienvenida a ${AppConfig.appName}',
              },
              style: text.headlineMedium,
            ),
            switch (state) {
              SessionActive(:final user, :final remember) => _SessionCard(user: user, remember: remember),
              SessionGuest(offline: true) => MessageBanner(
                  'No pudimos conectar con el servidor para revisar tu sesión.',
                  action: TextButton(
                    onPressed: () => session.add(const SessionChecked()),
                    child: const Text('Reintentar'),
                  ),
                ),
              SessionGuest() => const _GuestCard(),
              SessionChecking() => const LinearProgressIndicator(),
            },
          ],
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final compact = context.windowSize == WindowSize.compact;
    final buttons = [
      AppButton(label: 'Iniciar sesión', expand: compact, onPressed: () => Routes.toLogin(context)),
      AppButton.outlined(label: 'Crear cuenta', expand: compact, onPressed: () => Routes.toRegister(context)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inicia sesión para ver tus datos', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Con tu cuenta puedes reservar y ver tus citas.',
              style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (compact)
              Column(spacing: 10, children: buttons)
            else
              Wrap(spacing: 12, runSpacing: 10, children: buttons),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.user, required this.remember});

  final SessionUser user;
  final bool remember;

  static String _date(DateTime date) {
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  static String _method(TwoFactorMethod method) => switch (method) {
        TwoFactorMethod.email => 'Por correo',
        TwoFactorMethod.whatsapp => 'Por WhatsApp',
        TwoFactorMethod.totp => 'App de autenticación',
      };

  StatusChip _verified(bool verified) => verified
      ? const StatusChip(label: 'Verificado', tone: StatusTone.success)
      : const StatusChip(label: 'Sin verificar', tone: StatusTone.warning);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final rows = <(String, Widget)>[
      ('Nombre', Text(user.name)),
      ('Usuario', Text('@${user.nickname}')),
      ('Correo', Text(user.email)),
      ('Estado del correo', _verified(user.emailVerified)),
      if (user.pendingEmail case final email?) ('Correo por confirmar', Text(email)),
      ('Teléfono', Text(user.phone)),
      ('Estado del teléfono', _verified(user.phoneVerified)),
      if (user.pendingPhone case final phone?) ('Teléfono por confirmar', Text(phone)),
      (
        'Verificación en dos pasos',
        switch (user.twoFactor) {
          null => const StatusChip(label: 'Desactivada', tone: StatusTone.neutral),
          final method => StatusChip(label: _method(method), tone: StatusTone.success),
        },
      ),
      (
        'Google',
        user.googleLinked
            ? const StatusChip(label: 'Vinculado', tone: StatusTone.success)
            : const StatusChip(label: 'No vinculado', tone: StatusTone.neutral),
      ),
      ('Roles', Text(user.roles.isEmpty ? 'Sin roles' : user.roles.join(', '))),
      ('Cuenta creada', Text(_date(user.createdAt))),
      ('Recordar sesión', Text(remember ? 'Sí, en este dispositivo' : 'No')),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'TU SESIÓN',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            for (final (i, (label, value)) in rows.indexed) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  spacing: 16,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(label, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: DefaultTextStyle.merge(
                          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                          child: value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
