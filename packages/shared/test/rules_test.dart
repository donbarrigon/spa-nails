import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  group('Rules.normalizePhone', () {
    test('quita separadores y cambia 00 por +', () {
      expect(Rules.normalizePhone('0057 300-123 4567'), '+573001234567');
      expect(Rules.normalizePhone('+57 (300) 123.45.67'), '+573001234567');
    });
  });

  group('Rules.isEmailOrPhone', () {
    test('acepta email o teléfono con código conocido', () {
      expect(Rules.isEmailOrPhone('ana@correo.com'), isTrue);
      expect(Rules.isEmailOrPhone('+573001234567'), isTrue);
    });

    test('rechaza teléfono sin código o con código inexistente', () {
      expect(Rules.isEmailOrPhone('3001234567'), isFalse);
      // +80 no es un código asignado.
      expect(Rules.isEmailOrPhone('+801234567'), isFalse);
      expect(Rules.isEmailOrPhone('ana@correo'), isFalse);
    });
  });

  group('Rules.isUsername', () {
    test('acepta letras con tilde, números y signos sueltos', () {
      expect(Rules.isUsername('maría.r_2', 3, 30), isTrue);
    });

    test('rechaza inicio sin letra, signos seguidos y final en signo', () {
      expect(Rules.isUsername('2ana', 3, 30), isFalse);
      expect(Rules.isUsername('ana__r', 3, 30), isFalse);
      expect(Rules.isUsername('ana.', 3, 30), isFalse);
      expect(Rules.isUsername('an', 3, 30), isFalse);
      expect(Rules.isUsername('ana r', 3, 30), isFalse);
    });
  });

  test('Rules.isAlphaSpaces acepta tildes y ñ', () {
    expect(Rules.isAlphaSpaces('Ana Peña Ríos'), isTrue);
    expect(Rules.isAlphaSpaces('Ana 2'), isFalse);
  });
}
