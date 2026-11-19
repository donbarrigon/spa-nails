import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared/shared.dart';

import 'core/bloc/bloc_provider.dart';
import 'core/bloc/bloc_widgets.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/session/session_bloc.dart';
import 'shell/app_shell.dart';
import 'shell/splash_page.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _navigator = GlobalKey<NavigatorState>();

  SessionBloc get _session => BlocProvider.of<SessionBloc>(context);

  @override
  void initState() {
    super.initState();
    // Se revisa aquí y no en main: así el listener de abajo ya escucha cuando
    // llega el resultado.
    _session.add(const SessionChecked());
  }

  /// Al abrir sin sesión recordada se ofrece el login, con "Ahora no".
  void _onSession(BuildContext context, SessionState state) {
    if (state case SessionGuest(promptLogin: true)) {
      _navigator.currentState?.pushNamed(Routes.login);
    }
  }

  /// El tema elegido en las preferencias; sin sesión o sin elegir, el del dispositivo.
  static ThemeMode _themeMode(SessionState state) => switch (state) {
        SessionActive(:final user) => switch (user.theme) {
            ThemePreference.light => ThemeMode.light,
            ThemePreference.dark => ThemeMode.dark,
            null => ThemeMode.system,
          },
        _ => ThemeMode.system,
      };

  @override
  Widget build(BuildContext context) => BlocBuilder<SessionState>(
        bloc: _session,
        builder: (context, state) => _app(_themeMode(state)),
      );

  Widget _app(ThemeMode themeMode) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorKey: _navigator,
        onGenerateRoute: onGenerateRoute,
        builder: (context, child) => BlocListener<SessionState>(
          bloc: _session,
          listener: _onSession,
          child: child!,
        ),
        home: BlocBuilder<SessionState>(
          bloc: _session,
          builder: (context, state) =>
              state is SessionChecking ? const SplashPage() : const AppShell(),
        ),
      );
}
