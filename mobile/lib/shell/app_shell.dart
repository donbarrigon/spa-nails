import 'package:flutter/material.dart';

import '../core/layout.dart';
import '../features/home/home_page.dart';
import 'app_drawer.dart';

/// Marco de la app. En celular y tablet el menú se abre con la hamburguesa;
/// en escritorio queda fijo a la izquierda.
///
/// Por ahora hay una sola sección (Inicio). Cuando haya una segunda se agregan
/// la barra inferior (celular) / lateral (tablet y escritorio) y un `Navigator`
/// por pestaña para que cada una conserve su estado.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.windowSize == WindowSize.expanded) {
      return const Scaffold(
        body: Row(
          children: [
            SizedBox(width: 300, child: AppDrawer(permanent: true)),
            VerticalDivider(width: 1),
            Expanded(child: HomePage()),
          ],
        ),
      );
    }
    return const Scaffold(drawer: AppDrawer(), body: HomePage());
  }
}
