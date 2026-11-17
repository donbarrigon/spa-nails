import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Respuesta correcta (`2xx`) de la API, con el body ya decodificado.
final class ApiResponse {
  const ApiResponse(this.status, this.body);

  final int status;
  final Object? body;

  Map<String, Object?> get json => body as Map<String, Object?>;
}

/// Habla JSON con el backend y lleva la cookie de sesión.
///
/// En el navegador la cookie la maneja el navegador (es `HttpOnly`). Fuera de él
/// (mobile y escritorio) no hay quien la guarde, así que este cliente la lee de
/// cada `Set-Cookie` y la reenvía en `Cookie`.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.headers = const {},
    this.sessionCookie,
  }) : _http = httpClient ?? http.Client();

  /// Nombre de la cookie de sesión del backend (`session.cookie_name` en su env.json).
  static const sessionCookieName = 'forge_session';

  final Uri baseUrl;
  final http.Client _http;

  /// Headers extra en cada request (ej. `accept-language`).
  final Map<String, String> headers;

  /// Valor de la cookie de sesión; `null` sin sesión. Solo fuera del navegador.
  String? sessionCookie;

  /// Se llama cuando el backend cambia la cookie: login, logout o regeneración.
  void Function(String? value)? onSessionCookieChanged;

  Future<ApiResponse> get(String path) => _send('GET', path);

  Future<ApiResponse> post(String path, [Map<String, Object?>? body]) =>
      _send('POST', path, body);

  Future<ApiResponse> put(String path, [Map<String, Object?>? body]) =>
      _send('PUT', path, body);

  Future<ApiResponse> delete(String path, [Map<String, Object?>? body]) =>
      _send('DELETE', path, body);

  void close() => _http.close();

  Future<ApiResponse> _send(String method, String path, [Map<String, Object?>? body]) async {
    final request = http.Request(method, baseUrl.resolve(path))
      ..headers.addAll(headers)
      // Sin `accept` el backend responde MessagePack.
      ..headers['accept'] = 'application/json';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (sessionCookie case final cookie?) {
      request.headers['cookie'] = '$sessionCookieName=$cookie';
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on Exception catch (e) {
      throw ApiException.network(e.toString());
    }

    _readSessionCookie(response.headers['set-cookie']);

    final decoded = response.body.isEmpty ? null : _decode(response.body);
    if (response.statusCode >= 400) {
      throw ApiException.fromBody(response.statusCode, decoded);
    }
    return ApiResponse(response.statusCode, decoded);
  }

  static Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  /// `package:http` une varios `Set-Cookie` con comas; se busca solo la de sesión.
  void _readSessionCookie(String? header) {
    if (header == null) return;
    final match = RegExp('(?:^|,\\s*)$sessionCookieName=([^;,]*)([^,]*)').firstMatch(header);
    if (match == null) return;

    final value = match.group(1)!;
    final attributes = match.group(2)!.toLowerCase();
    final cleared = value.isEmpty || attributes.contains('max-age=0');
    final next = cleared ? null : value;
    if (next == sessionCookie) return;

    sessionCookie = next;
    onSessionCookieChanged?.call(next);
  }
}
