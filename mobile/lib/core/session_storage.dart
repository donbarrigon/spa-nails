import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda la cookie de sesión cuando el usuario marca "Recordarme".
///
/// Es una credencial (vale 30 días), por eso va al almacén seguro del sistema:
/// Keychain (iOS/macOS), Keystore (Android), Credential Manager (Windows) y
/// libsecret (Linux).
class SessionStorage {
  static const _key = 'session_cookie';

  // En macOS el llavero "legacy" no exige Keychain Sharing ni perfil de aprovisionamiento.
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  /// `null` si no hay sesión guardada o el almacén no está disponible.
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } on Exception catch (e) {
      debugPrint('SessionStorage.read: $e');
      return null;
    }
  }

  Future<void> write(String cookie) async {
    try {
      await _storage.write(key: _key, value: cookie);
    } on Exception catch (e) {
      // Sin almacén la sesión sigue en memoria: solo no se recuerda.
      debugPrint('SessionStorage.write: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Exception catch (e) {
      debugPrint('SessionStorage.clear: $e');
    }
  }
}
