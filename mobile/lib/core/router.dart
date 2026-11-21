import 'package:flutter/material.dart';

import '../features/auth/forgot_password/forgot_password_bloc.dart';
import '../features/auth/forgot_password/forgot_password_page.dart';
import '../features/auth/login/login_bloc.dart';
import '../features/auth/login/login_page.dart';
import '../features/auth/register/register_bloc.dart';
import '../features/auth/register/register_page.dart';
import 'bloc/bloc_provider.dart';
import 'deps.dart';

/// Rutas de pantalla completa (tapan el shell). La raíz `/` es el `home` de
/// `MaterialApp`: carga o shell según la sesión.
abstract final class Routes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static Future<void> toLogin(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).pushNamed(login);

  static Future<void> toRegister(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).pushNamed(register);

  /// Encima del login o del perfil; "atrás" vuelve a donde estaba. [user]
  /// prellena el correo o teléfono.
  static Future<void> toForgotPassword(BuildContext context, {String? user}) =>
      Navigator.of(context, rootNavigator: true).pushNamed(forgotPassword, arguments: user);

  /// Entre login y registro se reemplaza: "atrás" vuelve a la app, no al otro formulario.
  static void replaceWithLogin(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).pushReplacementNamed(login);

  static void replaceWithRegister(BuildContext context, {GoogleRegistration? google}) =>
      Navigator.of(context, rootNavigator: true).pushReplacementNamed(register, arguments: google);

  /// Cierra login/registro y vuelve al shell.
  static void backToApp(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
}

Route<Object?>? onGenerateRoute(RouteSettings settings) {
  final Widget Function(AppDeps deps)? page = switch (settings.name) {
    Routes.login => (deps) => BlocProvider(
          create: () => LoginBloc(userApi: deps.userApi, google: deps.google),
          child: const LoginPage(),
        ),
    Routes.register => (deps) => BlocProvider(
          create: () => RegisterBloc(userApi: deps.userApi, google: deps.google),
          child: RegisterPage(google: settings.arguments as GoogleRegistration?),
        ),
    Routes.forgotPassword => (deps) => BlocProvider(
          create: () => ForgotPasswordBloc(userApi: deps.userApi),
          child: ForgotPasswordPage(user: settings.arguments as String?),
        ),
    _ => null,
  };
  if (page == null) return null;

  return MaterialPageRoute(
    settings: settings,
    fullscreenDialog: true,
    builder: (context) => page(AppDeps.of(context)),
  );
}
