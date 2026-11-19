import 'dart:convert';

import 'package:client/client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

final _base = Uri.parse('https://spa.test');

void main() {
  test('por defecto pide y manda MessagePack', () async {
    late http.Request seen;
    final client = MockClient((r) async {
      seen = r;
      return http.Response.bytes(MsgPack.encode({'ok': true}), 200, headers: {'content-type': 'application/msgpack'});
    });

    final res = await fetch('/api/x', method: 'POST', body: {'a': 1}, baseUrl: _base, client: client);

    expect(seen.url, Uri.parse('https://spa.test/api/x'));
    expect(seen.headers['accept'], 'application/msgpack');
    expect(seen.headers['content-type'], 'application/msgpack');
    expect(MsgPack.decode(seen.bodyBytes), {'a': 1});
    expect(res.status, 200);
    expect(res.json, {'ok': true});
  });

  test('json, cookies y headers propios', () async {
    late http.Request seen;
    final client = MockClient((r) async {
      seen = r;
      return http.Response('{"n":1}', 201, headers: {'content-type': 'application/json'});
    });

    final res = await fetch(
      '/api/x',
      method: 'PUT',
      body: {'a': 'ñ'},
      encode: Encode.json,
      cookies: {'forge_session': 'abc', 'b': '2'},
      headers: {'x-csrf-token': 't', 'accept': 'text/plain'},
      baseUrl: _base,
      client: client,
    );

    expect(seen.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(seen.body), {'a': 'ñ'});
    expect(seen.headers['cookie'], 'forge_session=abc; b=2');
    expect(seen.headers['x-csrf-token'], 't');
    expect(seen.headers['accept'], 'text/plain', reason: 'los headers propios reemplazan a los de por defecto');
    expect(res.json, {'n': 1});
  });

  test('sin body no manda content-type', () async {
    late http.Request seen;
    final client = MockClient((r) async {
      seen = r;
      return http.Response('', 204);
    });

    final res = await fetch('/api/x', baseUrl: _base, client: client);

    expect(seen.method, 'GET');
    expect(seen.headers.containsKey('content-type'), isFalse);
    expect(res.body, isNull);
  });

  test('error con campos en MessagePack', () async {
    final client = MockClient((_) async => http.Response.bytes(
          MsgPack.encode({
            'status': 422,
            'message': 'Invalid data',
            'data': {
              'errors': {
                'email': ['Email already exists'],
              },
            },
          }),
          422,
          headers: {'content-type': 'application/msgpack'},
        ));

    await expectLater(
      fetch('/api/x', baseUrl: _base, client: client),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 422)
          .having((e) => e.fields, 'fields', {'email': 'Email already exists'})),
    );
  });

  test('sin conexión', () async {
    final client = MockClient((_) async => throw const SocketLikeException());

    await expectLater(
      fetch('/api/x', baseUrl: _base, client: client),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue)),
    );
  });
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}
