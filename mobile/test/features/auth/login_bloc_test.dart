import 'dart:convert';

import 'package:client/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared/shared.dart';
import 'package:spa_nails_mobile/core/google_auth.dart';
import 'package:spa_nails_mobile/features/auth/login/login_bloc.dart';

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

final _challenge = 'a' * 64;

/// Bloc contra un backend falso: [routes] responde por ruta.
LoginBloc _bloc(Map<String, http.Response Function(http.Request)> routes) {
  final api = ApiClient(
    baseUrl: Uri.parse('https://api.test'),
    httpClient: MockClient((r) async => routes[r.url.path]!(r)),
  );
  return LoginBloc(userApi: UserApi(api), google: GoogleAuth());
}

/// Envía [event] y devuelve el último estado cuando se calma.
Future<LoginState> _send(LoginBloc bloc, LoginEvent event) async {
  bloc.add(event);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return bloc.state;
}

UserLoginValidator _form({String user = 'ana@correo.com', String password = 'secreta123'}) =>
    UserLoginValidator(user: user, password: password, remember: true);

void main() {
  test('sin datos no llama a la API y marca los campos', () async {
    final bloc = _bloc({});
    final state = await _send(bloc, LoginSubmitted(_form(user: '', password: '')));

    expect(state, isA<LoginCredentials>());
    expect((state as LoginCredentials).fields.keys, containsAll(['user', 'password']));
  });

  test('sin segundo factor termina con la sesión', () async {
    final bloc = _bloc({'/api/users/auth/login': (_) => http.Response(jsonEncode(_user), 200)});
    final state = await _send(bloc, LoginSubmitted(_form()));

    expect(state, isA<LoginDone>());
    expect((state as LoginDone).remember, isTrue);
  });

  test('credenciales incorrectas muestran el error en español', () async {
    final bloc = _bloc({
      '/api/users/auth/login': (_) => http.Response('{"status":401,"message":"incorrect"}', 401),
    });
    final state = await _send(bloc, LoginSubmitted(_form()));

    expect((state as LoginCredentials).error, 'El correo, teléfono o contraseña no son correctos.');
  });

  group('segundo factor', () {
    late LoginBloc bloc;
    late http.Response Function(http.Request) twoFactor;

    setUp(() async {
      bloc = _bloc({
        '/api/users/auth/login': (_) => http.Response(
              jsonEncode({'challenge': _challenge, 'method': 'whatsapp', 'expires_in': 600}),
              202,
            ),
        '/api/users/auth/login/two-factor': (r) => twoFactor(r),
      });
      await _send(bloc, LoginSubmitted(_form()));
    });

    test('el 202 pasa al paso del código', () {
      expect(bloc.state, isA<LoginTwoFactor>());
      expect((bloc.state as LoginTwoFactor).challenge.method, TwoFactorMethod.whatsapp);
    });

    test('código mal escrito no llama a la API', () async {
      twoFactor = (_) => fail('no debía llamar a la API');
      final state = await _send(bloc, const TwoFactorSubmitted('12'));

      expect((state as LoginTwoFactor).codeError, 'El código tiene 6 dígitos');
    });

    test('código incorrecto queda en el campo', () async {
      twoFactor = (_) => http.Response('{"status":404,"message":"Invalid or expired code"}', 404);
      final state = await _send(bloc, const TwoFactorSubmitted('123456'));

      expect((state as LoginTwoFactor).codeError, 'El código no es correcto o ya venció.');
    });

    test('challenge vencido vuelve a las credenciales', () async {
      twoFactor = (_) => http.Response('{"status":401,"message":"expired"}', 401);
      final state = await _send(bloc, const TwoFactorSubmitted('123456'));

      expect(state, isA<LoginCredentials>());
    });

    test('código correcto termina con la sesión y conserva "Recordarme"', () async {
      twoFactor = (r) {
        expect(jsonDecode(r.body), {'challenge': _challenge, 'code': '123456'});
        return http.Response(jsonEncode(_user), 200);
      };
      final state = await _send(bloc, const TwoFactorSubmitted('123 456'));

      expect((state as LoginDone).remember, isTrue);
    });
  });
}
