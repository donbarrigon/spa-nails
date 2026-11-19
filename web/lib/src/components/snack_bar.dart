import 'dart:async';

import '../core/page.dart';

Timer? _timer;

/// Aviso pasajero abajo de la pantalla (SnackBar en mobile), ej. "Guardamos tus datos".
void showSnackBar(String message) {
  final bar = query('[data-snack-bar]');
  if (bar == null) return;
  bar
    ..textContent = message
    ..classList.add('snack-bar--visible');
  _timer?.cancel();
  _timer = Timer(const Duration(seconds: 4), () => bar.classList.remove('snack-bar--visible'));
}
