/// Cliente de la API del backend, compartido entre la app mobile y la web.
///
/// Dart puro: el transporte (`http.Client`) lo pone cada app.
library;

export 'src/api_client.dart';
export 'src/api_exception.dart';
export 'src/errors/auth_errors.dart';
export 'src/errors/profile_errors.dart';
export 'src/fetch.dart' show Encode, fetch;
export 'src/msgpack.dart';
export 'src/profile_api.dart';
export 'src/user_api.dart';
