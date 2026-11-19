import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../../components/app_button.dart';
import '../../../components/info_panel.dart';
import '../../../components/page_body.dart';
import '../../../components/user_avatar.dart';
import '../../../core/format.dart';
import '../profile_page.dart';
import '../widgets/account_labels.dart';

/// Pantalla principal del perfil: los datos del usuario por grupos. "Editar"
/// lleva a la pantalla del grupo, igual que la barra inferior o el panel lateral.
class ProfileOverview extends StatelessWidget {
  const ProfileOverview({super.key, required this.user, required this.onEdit});

  final SessionUser user;
  final ValueChanged<ProfileTab> onEdit;

  static const _empty = '—';

  static String themeLabel(ThemePreference? theme) => switch (theme) {
        ThemePreference.light => 'Claro',
        ThemePreference.dark => 'Oscuro',
        null => 'Según el dispositivo',
      };

  Widget _edit(ProfileTab tab) =>
      AppButton.text(label: 'Editar', icon: Icons.edit_outlined, onPressed: () => onEdit(tab));

  @override
  Widget build(BuildContext context) => PageBody(
        children: [
          _Header(user: user),
          InfoPanel(
            title: ProfileTab.account.title,
            icon: ProfileTab.account.icon,
            action: _edit(ProfileTab.account),
            rows: [
              ('Correo', Text(user.email)),
              ('Estado del correo', AccountLabels.verified(user.emailVerified)),
              ('Teléfono', Text(user.phone)),
              ('Estado del teléfono', AccountLabels.verified(user.phoneVerified)),
              ('Verificación en dos pasos', AccountLabels.twoFactor(user.twoFactor)),
              ('Google', AccountLabels.google(user.googleLinked)),
            ],
          ),
          InfoPanel(
            title: ProfileTab.personal.title,
            icon: ProfileTab.personal.icon,
            action: _edit(ProfileTab.personal),
            rows: [
              ('Nombre', Text(user.name)),
              ('Usuario', Text('@${user.nickname}')),
              ('Fecha de nacimiento', Text(switch (user.birthdate) {
                final date? => formatDate(date, utc: true),
                null => _empty,
              })),
              ('Documento', Text(switch ((user.documentType, user.document)) {
                (final type?, final number?) => '${type.code} $number',
                _ => _empty,
              })),
              ('Dirección', Text(user.address ?? _empty)),
              ('Ciudad', Text(user.city ?? _empty)),
            ],
          ),
          InfoPanel(
            title: ProfileTab.preferences.title,
            icon: ProfileTab.preferences.icon,
            action: _edit(ProfileTab.preferences),
            rows: [('Tema', Text(themeLabel(user.theme)))],
          ),
        ],
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        spacing: 16,
        children: [
          UserAvatar(name: user.name, size: 72),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(user.name, style: text.headlineSmall),
                Text(
                  '@${user.nickname}',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  'Cuenta creada el ${formatDate(user.createdAt)}',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
