import 'package:flutter/material.dart';

import '../../components/app_top_bar.dart';
import '../../core/bloc/bloc_provider.dart';
import '../../core/bloc/bloc_widgets.dart';
import '../../core/layout.dart';
import '../auth/session/session_bloc.dart';
import 'account/account_page.dart';
import 'overview/profile_overview.dart';
import 'personal/personal_page.dart';
import 'preferences/preferences_page.dart';

/// Pantallas del perfil.
enum ProfileTab {
  overview('Mi perfil', 'Perfil', Icons.person_outline, Icons.person),
  account('Autenticación', 'Acceso', Icons.lock_outline, Icons.lock),
  personal('Datos personales', 'Datos', Icons.badge_outlined, Icons.badge),
  preferences('Preferencias', 'Preferencias', Icons.tune_outlined, Icons.tune);

  const ProfileTab(this.title, this.shortLabel, this.icon, this.selectedIcon);

  final String title;

  /// Para la barra inferior, donde no cabe el título completo.
  final String shortLabel;
  final IconData icon;
  final IconData selectedIcon;
}

/// Perfil del usuario: un resumen y una pantalla por grupo. En celular y tablet
/// se cambia de pantalla con la barra inferior; en escritorio, con el panel de
/// la derecha. Los botones "Editar" del resumen llevan al mismo lugar.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ProfileTab _tab = ProfileTab.overview;

  void _select(ProfileTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) => BlocBuilder<SessionState>(
        bloc: BlocProvider.of<SessionBloc>(context),
        builder: (context, state) {
          // El shell solo muestra el perfil con sesión.
          if (state is! SessionActive) return const SizedBox.shrink();
          final user = state.user;

          // Cada pantalla conserva lo que se estaba escribiendo al cambiar de pestaña.
          final body = IndexedStack(
            index: _tab.index,
            children: [
              ProfileOverview(user: user, onEdit: _select),
              AccountPage(user: user),
              PersonalPage(user: user),
              PreferencesPage(user: user),
            ],
          );
          final appBar = AppTopBar(title: _tab.title, showMenu: true);

          if (context.windowSize == WindowSize.expanded) {
            return Scaffold(
              appBar: appBar,
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: body),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 280, child: _SidePanel(selected: _tab, onSelected: _select)),
                ],
              ),
            );
          }
          return Scaffold(
            appBar: appBar,
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab.index,
              onDestinationSelected: (i) => _select(ProfileTab.values[i]),
              destinations: [
                for (final tab in ProfileTab.values)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.shortLabel,
                    tooltip: tab.title,
                  ),
              ],
            ),
          );
        },
      );
}

/// Navegación del perfil en escritorio, a la derecha del contenido.
class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.selected, required this.onSelected});

  final ProfileTab selected;
  final ValueChanged<ProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              'TU CUENTA',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
            ),
          ),
          for (final tab in ProfileTab.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ListTile(
                selected: tab == selected,
                leading: Icon(tab == selected ? tab.selectedIcon : tab.icon),
                title: Text(tab.title),
                onTap: () => onSelected(tab),
              ),
            ),
        ],
      ),
    );
  }
}
