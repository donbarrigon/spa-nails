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
          passwordConfirmation: 'secreta123',
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

  group('confirmación de contraseña', () {
    test('el registro exige repetirla y que coincida', () {
      UserRegisterValidator form(String confirmation) => UserRegisterValidator(
            nickname: 'ana.perez',
            name: 'Ana Pérez',
            email: 'ana@correo.com',
            phone: '+573001234567',
            password: 'secreta123',
            passwordConfirmation: confirmation,
          );
      expect(form('').validate()['password_confirmation'], 'Repite la contraseña');
      expect(form('secreta12').validate()['password_confirmation'], 'Las contraseñas no coinciden');
      expect(form('secreta123').validate(), isEmpty);
    });

    test('no se envía al backend', () {
      final register = UserRegisterValidator(
        nickname: 'ana.perez',
        name: 'Ana Pérez',
        email: 'ana@correo.com',
        phone: '+573001234567',
        password: 'secreta123',
        passwordConfirmation: 'secreta123',
      );
      expect(register.toJson().containsKey('password_confirmation'), isFalse);
      final reset = ResetPasswordValidator(token: 'abc', password: 'secreta123', passwordConfirmation: 'secreta123');
      expect(reset.toJson().keys, ['token', 'password']);
    });

    test('restablecer con código valida que coincidan', () {
      final form = ResetPasswordCodeValidator(
        phone: '+573001234567',
        code: '123456',
        password: 'secreta123',
        passwordConfirmation: 'otra12345',
      )..prepareForValidation();
      expect(form.validate(), {'password_confirmation': 'Las contraseñas no coinciden'});
    });
  });

  group('RegisterAvailableValidator', () {
    test('normaliza según el campo y envía solo ese campo', () {
      final email = RegisterAvailableValidator(field: 'email', value: ' Ana@Correo.COM ')..prepareForValidation();
      expect(email.validate(), isEmpty);
      expect(email.toJson(), {'email': 'ana@correo.com'});

      final phone = RegisterAvailableValidator(field: 'phone', value: '+57 300-123 4567')..prepareForValidation();
      expect(phone.toJson(), {'phone': '+573001234567'});
    });

    test('con formato inválido no se envía', () {
      for (final (field, value) in [('nickname', '1ab'), ('email', 'ana@'), ('phone', '3001234567')]) {
        final form = RegisterAvailableValidator(field: field, value: value)..prepareForValidation();
        expect(form.validate().keys, [field], reason: field);
      }
    });
  });

  test('LoginTwoFactorValidator exige 6 dígitos', () {
    final form = LoginTwoFactorValidator(challenge: 'abc', code: '12 34 5')..prepareForValidation();
    expect(form.validate()['code'], 'El código tiene 6 dígitos');
  });
}
