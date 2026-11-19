import '../models/profile.dart';
import 'rules.dart';
import 'validator.dart';

// Espejo de `backend/src/app/handlers/users/validators/profile.rs`: mismos nombres,
// campos y reglas. Si una regla cambia allá, cambia acá.

/// `PUT /api/users/profile` — datos personales. Los opcionales vacíos se borran.
final class UpdateProfileValidator extends Validator {
  UpdateProfileValidator({
    required this.nickname,
    required this.name,
    this.birthdate = '',
    this.documentType,
    this.document = '',
    this.address = '',
    this.city = '',
  });

  String nickname;
  String name;

  /// `YYYY-MM-DD` o vacío.
  String birthdate;
  DocumentType? documentType;
  String document;
  String address;
  String city;

  @override
  void prepareForValidation() {
    nickname = nickname.trim();
    name = Rules.collapseSpaces(name);
    birthdate = birthdate.trim();
    document = document.replaceAll(RegExp(r'[.\s]'), '').toUpperCase();
    address = Rules.collapseSpaces(address);
    city = Rules.collapseSpaces(city);
  }

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('nickname', nickname.isNotEmpty, 'Elige un nombre de usuario');
    e.check(
      'nickname',
      Rules.isUsername(nickname, 3, 30),
      'De 3 a 30 caracteres. Empieza con una letra y usa letras, números, punto, guion o guion bajo',
    );

    e.check('name', name.isNotEmpty, 'Escribe tu nombre');
    e.check('name', Rules.isAlphaSpaces(name), 'Usa solo letras y espacios');
    e.check('name', Rules.length(name) >= 3, 'Escribe al menos 3 letras');
    e.check('name', Rules.length(name) <= 80, 'Usa máximo 80 caracteres');

    e.check(
      'birthdate',
      birthdate.isEmpty || Rules.parsePastDate(birthdate) != null,
      'Elige una fecha pasada',
    );

    e.check('document_type', documentType != null || document.isEmpty, 'Elige el tipo de documento');
    e.check(
      'document',
      documentType == null || document.isNotEmpty,
      'Escribe el número de documento',
    );
    e.check('document', Rules.isDocument(document, documentType), 'El número no corresponde al tipo de documento');

    e.check('address', Rules.length(address) <= 120, 'Usa máximo 120 caracteres');

    e.check('city', city.isEmpty || Rules.isAlphaSpaces(city), 'Usa solo letras y espacios');
    e.check('city', Rules.length(city) <= 60, 'Usa máximo 60 caracteres');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {
        'nickname': nickname,
        'name': name,
        'birthdate': birthdate,
        'document_type': documentType?.code,
        'document': document,
        'address': address,
        'city': city,
      };
}

/// `PUT /api/users/profile/preferences`.
final class PreferencesValidator extends Validator {
  PreferencesValidator({required this.theme});

  ThemePreference theme;

  @override
  Map<String, String> validate() => const {};

  @override
  Map<String, Object?> toJson() => {'theme': theme.name};
}
