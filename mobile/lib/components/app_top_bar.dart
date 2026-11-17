import 'package:flutter/material.dart';

/// Barra superior de las pantallas. Colores y letra vienen de `appBarTheme`.
///
/// Con [showMenu] muestra la hamburguesa que abre el menú del shell, solo si
/// el shell lo tiene como menú desplegable (en escritorio está siempre visible).
/// Sin [showMenu] ni [leading], `AppBar` pone la flecha atrás si se puede volver.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.showMenu = false,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool showMenu;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    // Cada página tiene su propio Scaffold: el menú está en el más externo (el del shell).
    final shell = context.findRootAncestorStateOfType<ScaffoldState>();
    final menu = showMenu && (shell?.hasDrawer ?? false)
        ? IconButton(
            tooltip: 'Menú',
            icon: const Icon(Icons.menu),
            onPressed: shell!.openDrawer,
          )
        : null;

    return AppBar(
      title: Text(title),
      leading: leading ?? menu,
      actions: [...actions, const SizedBox(width: 8)],
      bottom: bottom,
    );
  }
}
