/// JS de las páginas de auth: login, registro, verificar correo y recuperar contraseña.
library;

import 'package:spa_nails_web/src/auth/forgot_password_page.dart';
import 'package:spa_nails_web/src/auth/login_page.dart';
import 'package:spa_nails_web/src/auth/register_page.dart';
import 'package:spa_nails_web/src/auth/reset_password_page.dart';
import 'package:spa_nails_web/src/auth/verify_email_page.dart';

void main() {
  initLoginPage();
  initRegisterPage();
  initVerifyEmailPage();
  initForgotPasswordPage();
  initResetPasswordPage();
}
