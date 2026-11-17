import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  group('UserLoginValidator', () {
    test('normaliza el teléfono y valida', () {
      final form = UserLoginValidator(user: ' 0057 300 123 4567 ', password: 'secreta123')
        ..prepareForValidation();
      expect(form.user, '+573001234567');
      expect(form.validate(), isEmpty);
    });

    test('pasa el email a minúsculas', () {
      final form = UserLoginValidator(user: ' Ana@Correo.COM ', password: 'x')
        ..prepareForValidation();
      expect(form.user, 'ana@correo.com');
    });

    test('marca usuario y contraseña vacíos', () {
      final errors = (UserLoginValidator(user: '', password: '')..prepareForValidation()).validate();
      expect(errors.keys, containsAll(['user', 'password']));
    });

    test('solo envía method si viene', () {
      final json = UserLoginValidator(user: 'a@b.co', password: 'x').toJson();
      expect(json.containsKey('method'), isFalse);
    });
  });

  group('UserRegisterValidator', () {
    UserRegisterValidator valid() => UserRegisterValidator(
          nickname: 'ana.perez',
          name: '  Ana   Pérez ',
          email: 'ANA@correo.com',
          phone: '+57 300 123 4567',
          password: 'secreta123',
        );

    test('acepta un registro válido y lo normaliza', () {
      final form = valid()..prepareForValidation();
      expect(form.validate(), isEmpty);
      expect(form.name, 'Ana Pérez');
      expect(form.email, 'ana@correo.com');
      expect(form.phone, '+573001234567');
    });

    test('da un solo error por campo, el primero', () {
      final form = valid()
        ..name = ''
        ..password = '123'
        ..prepareForValidation();
      final errors = form.validate();
      expect(errors['name'], 'Escribe tu nombre');
      expect(errors['password'], 'Usa al menos 8 caracteres');
    });
  });

  test('LoginTwoFactorValidator exige 6 dígitos', () {
    final form = LoginTwoFactorValidator(challenge: 'abc', code: '12 34 5')..prepareForValidation();
    expect(form.validate()['code'], 'El código tiene 6 dígitos');
  });
}
