import 'package:client/client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:spa_nails_mobile/features/profile/profile_form.dart';

/// Envía [event] y devuelve los estados que salieron.
Future<List<ProfileFormState>> _send(ProfileFormSubmitted event) async {
  final bloc = ProfileFormBloc();
  final states = <ProfileFormState>[];
  final sub = bloc.stream.listen(states.add);
  bloc.add(event);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await sub.cancel();
  await bloc.dispose();
  return states;
}

void main() {
  test('con errores de validación no envía', () async {
    var sent = false;
    final form = PasswordValidator(password: '');
    final states = await _send(ProfileFormSubmitted(() async => sent = true, form: form));

    expect(sent, isFalse);
    expect(states.single, isA<ProfileFormIdle>().having((s) => s.fields.keys, 'fields', ['password']));
  });

  test('al terminar emite el resultado y vuelve a quedar libre', () async {
    final states = await _send(ProfileFormSubmitted(() async => 'ok'));

    expect(states[0], isA<ProfileFormIdle>().having((s) => s.submitting, 'submitting', isTrue));
    expect(states[1], isA<ProfileFormDone>().having((s) => s.result, 'result', 'ok'));
    expect(states[2], isA<ProfileFormIdle>().having((s) => s.submitting, 'submitting', isFalse));
  });

  test('contraseña incorrecta (403) va al campo de la contraseña', () async {
    final states = await _send(ProfileFormSubmitted(
      () async => throw const ApiException(403, 'The password is incorrect'),
    ));

    expect(
      states.last,
      isA<ProfileFormIdle>()
          .having((s) => s.fields['password'], 'password', ProfileErrors.wrongPassword)
          .having((s) => s.error, 'error', isNull),
    );
  });

  test('nombre de usuario repetido (409) va al campo', () async {
    final states = await _send(ProfileFormSubmitted(
      () async => throw const ApiException(409, 'Nickname already exists'),
    ));
    expect((states.last as ProfileFormIdle).fields, contains('nickname'));
  });

  test('sin conexión es un mensaje general', () async {
    final states = await _send(ProfileFormSubmitted(() async => throw const ApiException.network('x')));
    expect((states.last as ProfileFormIdle).error, isNotNull);
  });
}
