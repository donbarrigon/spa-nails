import 'package:flutter/material.dart';

import '../components/app_button.dart';
import '../components/brand_mark.dart';
import '../core/bloc/bloc_provider.dart';
import '../core/bloc/bloc_widgets.dart';
import '../core/router.dart';
import '../features/auth/session/session_bloc.dart';
import 'app_shell.dart';

/// Menú lateral: secciones arriba y la cuenta abajo.
/// [permanent]: fijo en la pantalla (escritorio) en vez de desplegable.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selected,
    required this.onSelected,
    this.permanent = false,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelected;
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final session = BlocProvider.of<SessionBloc>(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    /// Cierra el menú desplegable antes de navegar.
    void go(void Function() navigate) {
      if (!permanent) Scaffold.maybeOf(context)?.closeDrawer();
      navigate();
    }

    final content = SafeArea(
      child: BlocBuilder<SessionState>(
        bloc: session,
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Align(alignment: Alignment.centerLeft, child: BrandMark(size: 40)),
            ),
            if (state case SessionActive(:final user))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: text.titleMedium),
                    Text(
                      user.email,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            for (final section in AppSection.values)
              if (section != AppSection.profile || state is SessionActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    selected: section == selected,
                    leading: Icon(section.icon),
                    title: Text(section.label),
                    onTap: () => go(() => onSelected(section)),
                  ),
                ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: switch (state) {
                SessionActive() => AppButton.outlined(
                    label: 'Cerrar sesión',
                    icon: Icons.logout,
                    onPressed: () => go(() => session.add(const SessionLogoutRequested())),
                  ),
                // Botones secundarios: el principal ya está en el contenido.
                SessionGuest() => Column(
                    spacing: 4,
                    children: [
                      AppButton.outlined(
                        label: 'Iniciar sesión',
                        onPressed: () => go(() => Routes.toLogin(context)),
                      ),
                      AppButton.text(
                        label: 'Crear cuenta',
                        expand: true,
                        onPressed: () => go(() => Routes.toRegister(context)),
                      ),
                    ],
                  ),
                SessionChecking() => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );

    return permanent
        ? Material(color: scheme.surfaceContainerLow, child: content)
        : Drawer(child: content);
  }
}
