import 'package:client/client.dart';
import 'package:web/web.dart' as web;

import '../components/app_button.dart';
import '../components/snack_bar.dart';
import '../core/page.dart';

/// Marco de la app: abrir y cerrar el menú lateral y cerrar sesión.
void initAppShell() {
  final drawer = query('#app-drawer');
  if (drawer == null) return;
  final body = web.document.body!;
  final openButton = query('[data-drawer-open]');

  void setOpen(bool open) {
    body.classList.toggle('drawer-open', open);
    openButton?.setAttribute('aria-expanded', '$open');
    if (open) (query('a, button', drawer) as web.HTMLElement?)?.focus();
  }

  openButton?.onClick.listen((_) => setOpen(true));
  for (final close in queryAll('[data-drawer-close]')) {
    close.onClick.listen((_) => setOpen(false));
  }
  web.EventStreamProviders.keyDownEvent.forTarget(web.document).listen((e) {
    if (e.key == 'Escape' && body.classList.contains('drawer-open')) {
      setOpen(false);
      (openButton as web.HTMLElement?)?.focus();
    }
  });

  for (final logout in queryAll('[data-action="logout"]', drawer)) {
    final button = AppButton(logout);
    logout.onClick.listen((_) async {
      button.loading = true;
      try {
        await api('/api/users/auth/logout');
        go('/');
      } on ApiException catch (e) {
        button.loading = false;
        showSnackBar(AuthErrors.of(e));
      }
    });
  }
}
