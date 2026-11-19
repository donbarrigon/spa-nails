/// JS de todas las páginas: el menú lateral, cerrar sesión y los botones para
/// mostrar las contraseñas.
library;

import 'package:spa_nails_web/src/components/app_text_field.dart';
import 'package:spa_nails_web/src/shell/app_shell.dart';

void main() {
  initAppShell();
  AppTextField.initPasswordToggles();
}
