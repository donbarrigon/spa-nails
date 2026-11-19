import '../models/profile.dart';
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

  static final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Fecha `YYYY-MM-DD` entre 1900 y hoy, a medianoche UTC; `null` si no lo es.
  /// Igual que `parse_date` de `validators::profile` del backend.
  static DateTime? parsePastDate(String value, {DateTime? today}) {
    final match = _isoDate.firstMatch(value);
    if (match == null) return null;
    final [y, m, d] = [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
    final date = DateTime.utc(y, m, d);
    // `DateTime` corre los días inválidos (30 de febrero → 2 de marzo).
    if (date.month != m || date.day != d) return null;
    final now = (today ?? DateTime.now()).toUtc();
    if (date.isBefore(DateTime.utc(1900)) || date.isAfter(DateTime.utc(now.year, now.month, now.day))) {
      return null;
    }
    return date;
  }

  /// Formato del documento según su tipo; sin tipo, el documento va vacío.
  /// Igual que `document_for_type` de `validators::profile` del backend.
  static bool isDocument(String value, DocumentType? type) {
    bool digits(int min, int max) =>
        value.length >= min && value.length <= max && RegExp(r'^[0-9]+$').hasMatch(value);
    return switch (type) {
      null => value.isEmpty,
      DocumentType.cc || DocumentType.ti => digits(6, 10),
      DocumentType.ppt => digits(6, 12),
      DocumentType.nit => RegExp(r'^[0-9]{9,10}(-[0-9])?$').hasMatch(value),
      DocumentType.ce || DocumentType.pp => RegExp(r'^[A-Za-z0-9]{5,15}$').hasMatch(value),
    };
  }

  /// Fecha como `YYYY-MM-DD` (la parte UTC).
  static String isoDate(DateTime date) {
    final d = date.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }

  /// Quita espacios de los extremos y deja uno solo entre palabras.
  static String collapseSpaces(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
