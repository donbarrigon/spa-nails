import 'package:shared/shared.dart';
import 'package:test/test.dart';

void main() {
  test('SessionUser lee el JSON extendido de Mongo', () {
    final user = SessionUser.fromJson({
      'id': {r'$oid': '6650f0c2a1b2c3d4e5f60718'},
      'nickname': 'ana.perez',
      'name': 'Ana Pérez',
      'avatar': '',
      'email': 'ana@correo.com',
      'phone': '+573001234567',
      'email_verified_at': {
        r'$date': {r'$numberLong': '1700000000000'},
      },
      'two_factor': 'whatsapp',
      'google_linked': true,
      'roles': ['client'],
      'permissions': <String>[],
      'created_at': {
        r'$date': {r'$numberLong': '1700000000000'},
      },
      'updated_at': '2026-11-16T10:00:00Z',
    });

    expect(user.id, '6650f0c2a1b2c3d4e5f60718');
    expect(user.emailVerified, isTrue);
    expect(user.phoneVerified, isFalse);
    expect(user.twoFactor, TwoFactorMethod.whatsapp);
    expect(user.createdAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
    expect(user.updatedAt, DateTime.utc(2026, 11, 16, 10));
  });

  test('SessionUser lee los datos del perfil y las preferencias', () {
    final user = SessionUser.fromJson({
      'id': '6650f0c2a1b2c3d4e5f60718',
      'nickname': 'ana.perez',
      'name': 'Ana Pérez',
      'avatar': '',
      'email': 'ana@correo.com',
      'phone': '+573001234567',
      'birthdate': {
        r'$date': {r'$numberLong': '642902400000'},
      },
      'document_type': 'CC',
      'document': '1020304050',
      'city': 'Bogotá',
      'preferences': {'theme': 'dark'},
      'created_at': '2026-11-16T10:00:00Z',
      'updated_at': '2026-11-16T10:00:00Z',
    });

    expect(user.birthdate, DateTime.utc(1990, 5, 17));
    expect(user.documentType, DocumentType.cc);
    expect(user.address, isNull);
    expect(user.theme, ThemePreference.dark);
  });

  test('sin preferencias el tema es null', () {
    final user = SessionUser.fromJson({
      'id': '6650f0c2a1b2c3d4e5f60718',
      'nickname': 'ana.perez',
      'name': 'Ana Pérez',
      'email': 'ana@correo.com',
      'phone': '+573001234567',
      'preferences': null,
      'created_at': '2026-11-16T10:00:00Z',
      'updated_at': '2026-11-16T10:00:00Z',
    });
    expect(user.theme, isNull);
  });
}
