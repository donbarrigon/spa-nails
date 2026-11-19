import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateProfileValidator', () {
    UpdateProfileValidator valid() => UpdateProfileValidator(
          nickname: ' ana.perez ',
          name: '  Ana   Pérez ',
          birthdate: '1990-05-17',
          documentType: DocumentType.cc,
          document: '1.020.304.050',
          address: ' Calle  10 # 20-30 ',
          city: ' Bogotá ',
        );

    test('acepta datos válidos y los normaliza', () {
      final form = valid()..prepareForValidation();
      expect(form.validate(), isEmpty);
      expect(form.nickname, 'ana.perez');
      expect(form.name, 'Ana Pérez');
      expect(form.document, '1020304050');
      expect(form.address, 'Calle 10 # 20-30');
      expect(form.toJson()['document_type'], 'CC');
    });

    test('los opcionales pueden ir vacíos', () {
      final form = UpdateProfileValidator(nickname: 'ana.perez', name: 'Ana Pérez')
        ..prepareForValidation();
      expect(form.validate(), isEmpty);
      expect(form.toJson()['document_type'], isNull);
    });

    test('documento sin tipo o tipo sin documento', () {
      final noType = (valid()..documentType = null)..prepareForValidation();
      expect(noType.validate().keys, contains('document_type'));

      final noNumber = (valid()..document = '')..prepareForValidation();
      expect(noNumber.validate().keys, contains('document'));
    });

    test('fecha futura y ciudad con números', () {
      final form = (valid()
            ..birthdate = '2999-01-01'
            ..city = 'Bogotá 2')
        ..prepareForValidation();
      expect(form.validate().keys, containsAll(['birthdate', 'city']));
    });
  });

  group('Rules', () {
    test('parsePastDate', () {
      final today = DateTime.utc(2026, 11, 17);
      expect(Rules.parsePastDate('1990-05-17', today: today), DateTime.utc(1990, 5, 17));
      expect(Rules.parsePastDate('2026-11-17', today: today), isNotNull);
      expect(Rules.parsePastDate('2026-11-18', today: today), isNull);
      expect(Rules.parsePastDate('1899-12-31', today: today), isNull);
      expect(Rules.parsePastDate('1990-02-30', today: today), isNull);
      expect(Rules.parsePastDate('17/05/1990', today: today), isNull);
    });

    test('isDocument según el tipo', () {
      expect(Rules.isDocument('', null), isTrue);
      expect(Rules.isDocument('123', null), isFalse);
      expect(Rules.isDocument('1020304050', DocumentType.cc), isTrue);
      expect(Rules.isDocument('AB12345', DocumentType.cc), isFalse);
      expect(Rules.isDocument('900123456-7', DocumentType.nit), isTrue);
      expect(Rules.isDocument('AB123456', DocumentType.pp), isTrue);
    });

    test('isoDate usa el día UTC', () {
      expect(Rules.isoDate(DateTime.utc(1990, 5, 7)), '1990-05-07');
    });
  });

  group('cuenta', () {
    test('ChangeEmailValidator normaliza y pide contraseña', () {
      final form = ChangeEmailValidator(email: ' Ana@Correo.COM ', password: '')..prepareForValidation();
      expect(form.email, 'ana@correo.com');
      expect(form.validate().keys, ['password']);
    });

    test('ChangePasswordValidator usa los nombres del backend', () {
      final form = ChangePasswordValidator(currentPassword: '', password: 'corta');
      expect(form.validate().keys, containsAll(['current_password', 'password']));
      expect(form.toJson().keys, ['current_password', 'password']);
    });

    test('CodeValidator quita espacios', () {
      final form = CodeValidator(code: '123 456')..prepareForValidation();
      expect(form.validate(), isEmpty);
      expect(form.toJson(), {'code': '123456'});
    });
  });

  test('PreferencesValidator envía el tema', () {
    expect(PreferencesValidator(theme: ThemePreference.dark).toJson(), {'theme': 'dark'});
  });
}
