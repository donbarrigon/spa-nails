import 'package:shared/shared.dart';

import 'api_client.dart';

/// Rutas `/api/users/profile/...`. Responden el usuario de la sesión actualizado.
///
/// Los métodos reciben el validador ya validado: solo envían su `toJson`.
class ProfileApi {
  ProfileApi(this._api);

  final ApiClient _api;

  /// Datos personales. `409` si el nombre de usuario ya es de otra cuenta.
  Future<SessionUser> update(UpdateProfileValidator form) async =>
      _user(await _api.put('/api/users/profile', form.toJson()));

  Future<SessionUser> updatePreferences(PreferencesValidator form) async =>
      _user(await _api.put('/api/users/profile/preferences', form.toJson()));

  static SessionUser _user(ApiResponse res) => SessionUser.fromJson(res.json);
}
