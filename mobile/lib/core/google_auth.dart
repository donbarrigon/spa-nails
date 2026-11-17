import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

import 'config.dart';

/// Cuenta de Google con la que el usuario se identificó.
final class GoogleIdentity {
  const GoogleIdentity({required this.idToken, required this.email, this.name});

  /// Lo verifica el backend en cada request.
  final String idToken;
  final String email;
  final String? name;
}

/// Falló Google Sign-In (no cuando el usuario cancela).
final class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);
  final String message;

  @override
  String toString() => 'GoogleAuthException: $message';
}

/// Envoltorio de `google_sign_in`. Solo funciona en Android, iOS y macOS, y
/// cuando `GOOGLE_SERVER_CLIENT_ID` está configurado.
class GoogleAuth {
  Future<void>? _initialized;

  bool get isAvailable =>
      AppConfig.googleServerClientId.isNotEmpty &&
      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  /// Abre el selector de cuentas. `null` si el usuario cancela.
  Future<GoogleIdentity?> signIn() async {
    if (!isAvailable) throw const GoogleAuthException('Google Sign-In no está disponible');
    await (_initialized ??= GoogleSignIn.instance.initialize(
      clientId: AppConfig.googleClientId.isEmpty ? null : AppConfig.googleClientId,
      serverClientId: AppConfig.googleServerClientId,
    ));

    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const GoogleAuthException('Google no devolvió el ID token');
      return GoogleIdentity(idToken: idToken, email: account.email, name: account.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw GoogleAuthException(e.description ?? e.code.name);
    }
  }

  /// Para que el próximo login vuelva a mostrar el selector de cuentas.
  Future<void> signOut() async {
    if (_initialized == null) return;
    await _initialized;
    await GoogleSignIn.instance.signOut();
  }
}
