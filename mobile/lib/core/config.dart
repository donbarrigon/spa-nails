import 'package:flutter/foundation.dart';

/// Configuración de la app. Sale de `mobile/env.json`, que se pasa al compilar:
/// `flutter run --dart-define-from-file=env.json` (ver `just mobile`).
abstract final class AppConfig {
  /// Nombre del local que se muestra en la app.
  static const appName = String.fromEnvironment('APP_NAME');

  /// URL del backend. En el emulador de Android `localhost` es el propio
  /// emulador: el equipo se alcanza con `https://10.0.2.2:8432`.
  static const apiUrl = String.fromEnvironment('API_URL');

  /// Acepta el certificado autofirmado del backend en desarrollo
  /// (`server.auto_cert`). Nunca aplica en compilaciones release.
  static const allowBadCertificates =
      bool.fromEnvironment('ALLOW_BAD_CERTIFICATES') && !kReleaseMode;

  /// Client ID de Google para iOS y macOS. En Android no se usa.
  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  /// Client ID "web" de Google: es la audiencia del ID token que verifica el
  /// backend (debe estar en `extensions.google.client_ids` de su env.json).
  /// Vacío = el login con Google no se muestra.
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Falla al arrancar si la app se compiló sin `env.json`.
  static void ensureLoaded() {
    if (appName.isEmpty || apiUrl.isEmpty) {
      throw StateError(
        'Falta la configuración: ejecuta con --dart-define-from-file=env.json',
      );
    }
  }
}
