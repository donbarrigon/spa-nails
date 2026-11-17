import 'phone_codes.dart';

/// Reglas de formato con los mismos patrones que ironforge
/// (`ironforge::validator::format`) y `validators::user` del backend.
abstract final class Rules {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phoneCode = RegExp(r'^\+[1-9]\d{7,14}$');
  static final _alphaSpaces = RegExp(r'^[\p{L}\p{M} ]+$', unicode: true);
  static final _letter = RegExp(r'^\p{L}$', unicode: true);
  static final _alphaNum = RegExp(r'^[\p{L}\p{N}]$', unicode: true);
  static final _code = RegExp(r'^[0-9]{6}$');

  /// Longitud en caracteres (no en unidades UTF-16), como `chars().count()` en Rust.
  static int length(String value) => value.runes.length;

  static bool isEmail(String value) => _email.hasMatch(value);

  /// Teléfono con código de país, ej. `+573001234567`.
  static bool isPhoneCode(String value) => _phoneCode.hasMatch(value);

  /// Empieza con un código de país conocido.
  static bool knownPhoneCode(String value) {
    // Los códigos tienen de 1 a 3 dígitos: se prueba cada prefijo posible.
    for (var digits = 1; digits <= 3 && digits < value.length; digits++) {
      if (phoneCodes.contains(value.substring(0, digits + 1))) return true;
    }
    return false;
  }

  /// Email válido, o teléfono con código de país conocido.
  static bool isEmailOrPhone(String value) => value.contains('@')
      ? isEmail(value)
      : isPhoneCode(value) && knownPhoneCode(value);

  /// Solo letras (con tildes) y espacios.
  static bool isAlphaSpaces(String value) => _alphaSpaces.hasMatch(value);

  /// Código de 6 dígitos (email, WhatsApp o app de autenticación).
  static bool isCode(String value) => _code.hasMatch(value);

  /// Igual que `re_username` de ironforge: de [min] a [max] caracteres, empieza con
  /// letra, solo letras, números, `.`, `_` y `-`, sin dos signos seguidos y sin
  /// terminar en signo.
  static bool isUsername(String value, int min, int max) {
    final chars = value.runes.map(String.fromCharCode).toList();
    if (chars.length < min || chars.length > max) return false;
    if (!_letter.hasMatch(chars.first)) return false;

    String? prev;
    for (final c in chars) {
      final alphaNum = _alphaNum.hasMatch(c);
      if (!alphaNum && !const {'.', '_', '-'}.contains(c)) return false;
      if (!alphaNum && prev != null && !_alphaNum.hasMatch(prev)) return false;
      prev = c;
    }
    return _alphaNum.hasMatch(prev!);
  }

  /// Quita espacios y separadores (`-`, `.`, `(`, `)`) y cambia el prefijo
  /// internacional `00` por `+`: `0057 300-123 4567` → `+573001234567`.
  static String normalizePhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[\s\-.()]'), '');
    return clean.startsWith('00') ? '+${clean.substring(2)}' : clean;
  }

  /// Quita espacios de los extremos y deja uno solo entre palabras.
  static String collapseSpaces(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
