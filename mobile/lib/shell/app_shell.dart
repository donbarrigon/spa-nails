import 'package:flutter/material.dart';

import '../core/bloc/bloc_provider.dart';
import '../core/bloc/bloc_widgets.dart';
import '../core/layout.dart';
import '../features/auth/session/session_bloc.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';
import 'app_drawer.dart';

/// Secciones del menú lateral.
enum AppSection {
  home('Inicio', Icons.home_outlined),

  /// Solo con sesión.
  profile('Mi perfil', Icons.person_outline);

  const AppSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Marco de la app. En celular y tablet el menú se abre con la hamburguesa;
/// en escritorio queda fijo a la izquierda.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.home;

  @override
  Widget build(BuildContext context) => BlocBuilder<SessionState>(
        bloc: BlocProvider.of<SessionBloc>(context),
        builder: (context, state) {
          // Al cerrar sesión desde el perfil se vuelve a Inicio.
          final section = state is SessionActive ? _section : AppSection.home;
          final drawer = AppDrawer(
            selected: section,
            onSelected: (s) => setState(() => _section = s),
            permanent: context.windowSize == WindowSize.expanded,
          );
          final page = switch (section) {
            AppSection.home => const HomePage(),
            AppSection.profile => const ProfilePage(),
          };

          if (context.windowSize == WindowSize.expanded) {
            return Scaffold(
              body: Row(
                children: [
                  SizedBox(width: 300, child: drawer),
                  const VerticalDivider(width: 1),
                  Expanded(child: page),
                ],
              ),
            );
          }
          return Scaffold(drawer: drawer, body: page);
        },
      );
}
