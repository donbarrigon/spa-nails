import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_client.dart' show ApiResponse;
import 'api_exception.dart';
import 'msgpack.dart';

/// Formato del body que se envía y del que se pide de vuelta (`accept`).
enum Encode {
  /// El formato por defecto del backend (ironforge).
  msgpack('application/msgpack'),
  json('application/json');

  const Encode(this.mime);

  final String mime;

  Uint8List encode(Object? body) => switch (this) {
        msgpack => MsgPack.encode(body),
        json => utf8.encode(jsonEncode(body)),
      };
}

/// Hace un request al backend y devuelve el body ya decodificado.
///
/// - `path`: relativo a [baseUrl] (por defecto la página actual en el
///   navegador), ej. `/api/users/auth/login`. También acepta una URL completa.
/// - `encode`: formato del `body` y del `accept`. Por defecto MessagePack.
/// - `headers`: se agregan (o reemplazan) a los de por defecto.
/// - `cookies`: se envían en `cookie`. Solo fuera del navegador: el navegador
///   no deja poner ese header y manda las suyas solo.
///
/// La respuesta se decodifica según su `content-type` (MessagePack, JSON o
/// texto). Si el estado es `>= 400` lanza [ApiException]; sin conexión,
/// [ApiException.network].
Future<ApiResponse> fetch(
  String path, {
  String method = 'GET',
  Object? body,
  Encode encode = Encode.msgpack,
  Map<String, String> headers = const {},
  Map<String, String> cookies = const {},
  Uri? baseUrl,
  http.Client? client,
}) async {
  final request = http.Request(method, (baseUrl ?? Uri.base).resolve(path))
    ..headers['accept'] = encode.mime;
  if (body != null) {
    request
      ..headers['content-type'] = encode.mime
      ..bodyBytes = encode.encode(body);
  }
  if (cookies.isNotEmpty) {
    request.headers['cookie'] = cookies.entries.map((c) => '${c.key}=${c.value}').join('; ');
  }
  request.headers.addAll(headers);

  final http_ = client ?? http.Client();
  final http.Response response;
  try {
    response = await http.Response.fromStream(await http_.send(request));
  } on Exception catch (e) {
    throw ApiException.network(e.toString());
  } finally {
    if (client == null) http_.close();
  }

  final decoded = decodeBody(response.headers['content-type'], response.bodyBytes);
  if (response.statusCode >= 400) {
    throw ApiException.fromBody(response.statusCode, decoded);
  }
  return ApiResponse(response.statusCode, decoded);
}

/// Body según su `content-type`; vacío → `null`. Si no se puede leer como
/// MessagePack o JSON se devuelve el texto tal cual.
Object? decodeBody(String? contentType, Uint8List bytes) {
  if (bytes.isEmpty) return null;
  final mime = contentType?.split(';').first.trim().toLowerCase();
  try {
    return switch (mime) {
      'application/msgpack' || 'application/x-msgpack' => MsgPack.decode(bytes),
      'application/json' => jsonDecode(utf8.decode(bytes)),
      _ => utf8.decode(bytes, allowMalformed: true),
    };
  } on FormatException {
    return utf8.decode(bytes, allowMalformed: true);
  }
}
