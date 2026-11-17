import 'package:client/client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/api.dart';
import 'core/bloc/bloc_provider.dart';
import 'core/config.dart';
import 'core/deps.dart';
import 'core/google_auth.dart';
import 'core/session_storage.dart';
import 'features/auth/session/session_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.ensureLoaded();
  _registerFontLicenses();

  final api = createApiClient();
  final userApi = UserApi(api);
  final google = GoogleAuth();
  final storage = SessionStorage();

  runApp(
    AppDeps(
      api: api,
      userApi: userApi,
      google: google,
      sessionStorage: storage,
      child: BlocProvider<SessionBloc>(
        create: () => SessionBloc(api: api, userApi: userApi, storage: storage, google: google),
        child: const App(),
      ),
    ),
  );
}

/// Las fuentes son OFL: su licencia aparece en la pantalla de licencias.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in [
      ('DM Sans', 'OFL-DMSans.txt'),
      ('Playfair Display', 'OFL-PlayfairDisplay.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}
