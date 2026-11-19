import 'package:client/client.dart';
import 'package:shared/shared.dart';
import 'package:web/web.dart' as web;

import '../components/message_banner.dart';
import '../components/snack_bar.dart';
import '../core/page.dart';

/// Preferencias: el tema claro u oscuro, que se aplica al instante.
void initPreferencesPage() {
  final options = queryAll('[data-theme-option]');
  if (options.isEmpty) return;
  final error = MessageBanner.byId('preferences-error');

  void select(ThemePreference theme) {
    for (final option in options) {
      option.setAttribute('aria-pressed', '${option.getAttribute('data-theme-option') == theme.name}');
    }
    web.document.documentElement!.setAttribute('data-theme', theme.name);
    query('#theme-help')!.textContent = 'Se aplica en todos tus dispositivos al iniciar sesión.';
  }

  for (final option in options) {
    final theme = ThemePreference.tryParse(option.getAttribute('data-theme-option'))!;
    option.onClick.listen((_) async {
      if (option.getAttribute('aria-pressed') == 'true') return;
      for (final o in options) {
        o.toggleAttribute('disabled', true);
      }
      error.message = null;
      try {
        await api(
          '/api/users/profile/preferences',
          method: 'PUT',
          body: PreferencesValidator(theme: theme).toJson(),
        );
        select(theme);
        showSnackBar(theme == ThemePreference.dark ? 'Tema oscuro activado' : 'Tema claro activado');
      } on ApiException catch (e) {
        error.message = ProfileErrors.of(e).$1 ?? AuthErrors.of(e);
      } finally {
        for (final o in options) {
          o.toggleAttribute('disabled', false);
        }
      }
    });
  }
}
