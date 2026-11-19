import 'dart:convert';

import 'package:client/client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared/shared.dart';
import 'package:test/test.dart';

const _user = {
  'id': {r'$oid': '6650f0c2a1b2c3d4e5f60718'},
  'nickname': 'ana.perez',
  'name': 'Ana Pérez',
  'avatar': '',
  'email': 'ana@correo.com',
  'phone': '+573001234567',
  'roles': <String>[],
  'permissions': <String>[],
  'created_at': '2026-11-16T10:00:00Z',
  'updated_at': '2026-11-16T10:00:00Z',
};

ApiClient _client(http.Response Function(http.Request) handler) => ApiClient(
      baseUrl: Uri.parse('https://api.test'),
      httpClient: MockClient((r) async => handler(r)),
    );

void main() {
  test('guarda la cookie del login y la reenvía', () async {
    final seen = <String?>[];
    final api = _client((r) {
      seen.add(r.headers['cookie']);
      return http.Response(jsonEncode(_user), 200, headers: {
        'set-cookie': 'other=1; Path=/, forge_session=abc123; Path=/; Max-Age=2592000; Secure; HttpOnly',
      });
    });
    String? changed;
    api.onSessionCookieChanged = (v) => changed = v;

    await UserApi(api).login(UserLoginValidator(user: 'ana@correo.com', password: 'secreta123'));
    await UserApi(api).me();

    expect(changed, 'abc123');
    expect(seen, [null, 'forge_session=abc123']);
  });

  test('borra la cookie con Max-Age=0', () async {
    final api = _client((_) => http.Response('', 204, headers: {
          'set-cookie': 'forge_session=; Path=/; Max-Age=0; Secure; HttpOnly',
        }))
      ..sessionCookie = 'abc123';

    await UserApi(api).logout();

    expect(api.sessionCookie, isNull);
  });

  test('pide JSON: sin accept el backend responde MessagePack', () async {
    final api = _client((r) {
      expect(r.headers['accept'], 'application/json');
      return http.Response(jsonEncode(_user), 200);
    });
    await UserApi(api).me();
  });

  test('202 del login es segundo factor', () async {
    final api = _client((_) => http.Response(
          jsonEncode({'challenge': 'f' * 64, 'method': 'email', 'expires_in': 600}),
          202,
        ));

    final result = await UserApi(api).login(UserLoginValidator(user: 'a@b.co', password: 'x'));

    expect(result, isA<TwoFactorRequired>());
    expect((result as TwoFactorRequired).challenge.method, TwoFactorMethod.email);
  });

  test('422 trae el primer error de cada campo', () async {
    final api = _client((_) => http.Response(
          jsonEncode({
            'status': 422,
            'message': 'Unprocessable Entity',
            'data': {
              'errors': {
                'email': ['the email field is required', 'other'],
              },
            },
          }),
          422,
        ));

    await expectLater(
      UserApi(api).logout(),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 422)
          .having((e) => e.fields, 'fields', {'email': 'the email field is required'})),
    );
  });

  test('me() con 401 es null, no error', () async {
    final api = _client((_) => http.Response('{"status":401,"message":"Unauthorized"}', 401));
    expect(await UserApi(api).me(), isNull);
  });

  test('sin conexión es ApiException.network', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.test'),
      httpClient: MockClient((_) => throw http.ClientException('Connection refused')),
    );
    await expectLater(
      UserApi(api).me(),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue)),
    );
  });

  test('ProfileApi envía PUT a las rutas de perfil y lee el usuario', () async {
    final seen = <String>[];
    final api = _client((r) {
      seen.add('${r.method} ${r.url.path} ${r.body}');
      return http.Response(jsonEncode({..._user, 'preferences': {'theme': 'dark'}}), 200);
    });

    final user = await ProfileApi(api).updatePreferences(PreferencesValidator(theme: ThemePreference.dark));
    await ProfileApi(api).update(UpdateProfileValidator(nickname: 'ana.perez', name: 'Ana Pérez'));

    expect(user.theme, ThemePreference.dark);
    expect(seen.first, 'PUT /api/users/profile/preferences {"theme":"dark"}');
    expect(seen.last, startsWith('PUT /api/users/profile {"nickname":"ana.perez"'));
  });
}
