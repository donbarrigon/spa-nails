import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../../components/info_panel.dart';
import '../../../components/message_banner.dart';
import '../../../components/page_body.dart';
import '../../../core/deps.dart';
import '../profile_form.dart';

/// Preferencias de la app. Por ahora, el tema claro u oscuro.
class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key, required this.user});

  final SessionUser user;

  @override
  Widget build(BuildContext context) => ProfileForm(
        builder: (context, state, submit) {
          final text = Theme.of(context).textTheme;
          final scheme = Theme.of(context).colorScheme;

          void choose(ThemePreference theme) {
            final form = PreferencesValidator(theme: theme);
            final api = AppDeps.of(context).profileApi;
            submit(() => api.updatePreferences(form), form: form);
          }

          return PageBody(
            children: [
              InfoPanel(
                title: 'Tema',
                icon: Icons.palette_outlined,
                footer: [
                  Text(
                    user.theme == null
                        ? 'Ahora la app usa el tema de tu dispositivo. Elige uno para usarlo siempre.'
                        : 'Se aplica en todos tus dispositivos al iniciar sesión.',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SegmentedButton<ThemePreference>(
                      segments: const [
                        ButtonSegment(
                          value: ThemePreference.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: ThemePreference.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Oscuro'),
                        ),
                      ],
                      selected: {?user.theme},
                      emptySelectionAllowed: true,
                      showSelectedIcon: false,
                      onSelectionChanged: state.submitting
                          ? null
                          : (selected) {
                              if (selected.singleOrNull case final theme?) choose(theme);
                            },
                    ),
                  ),
                  if (state.error case final error?) MessageBanner(error),
                ],
              ),
            ],
          );
        },
      );
}
