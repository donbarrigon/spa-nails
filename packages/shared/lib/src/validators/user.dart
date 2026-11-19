import '../models/two_factor.dart';
import 'rules.dart';
import 'validator.dart';

// Espejo de `backend/src/app/handler/validators/user.rs`: mismos nombres, campos
// y reglas. Si una regla cambia allá, cambia acá.

/// `POST /api/users/auth/login` — `user` es el email o el teléfono con código de país.
final class UserLoginValidator extends Validator {
  UserLoginValidator({
    required this.user,
    required this.password,
    this.remember = false,
    this.method,
  });

  String user;
  String password;
  bool remember;

  /// Por dónde enviar el código si la cuenta tiene segundo factor; si no viene,
  /// el backend usa el método preferido.
  TwoFactorMethod? method;

  bool get isEmail => user.contains('@');

  @override
  void prepareForValidation() {
    user = user.trim().toLowerCase();
    if (!isEmail) user = Rules.normalizePhone(user);
  }

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('user', user.isNotEmpty, 'Escribe tu correo o tu teléfono');
    e.check(
      'user',
      Rules.isEmailOrPhone(user),
      'Escribe un correo válido o un teléfono con código de país (ej. +57)',
    );
    // Sin reglas de longitud: el backend responde lo mismo que con credenciales
    // incorrectas para no revelar el formato.
    e.check('password', password.isNotEmpty, 'Escribe tu contraseña');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {
        'user': user,
        'password': password,
        'remember': remember,
        if (method != null) 'method': method!.name,
      };
}

/// `POST /api/users/auth/login/two-factor` — el `challenge` del primer paso y el código.
final class LoginTwoFactorValidator extends Validator {
  LoginTwoFactorValidator({required this.challenge, required this.code});

  String challenge;
  String code;

  @override
  void prepareForValidation() {
    challenge = challenge.trim();
    code = code.replaceAll(RegExp(r'\s'), '');
  }

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('code', code.isNotEmpty, 'Escribe el código');
    e.check('code', Rules.isCode(code), 'El código tiene 6 dígitos');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'challenge': challenge, 'code': code};
}

/// `POST /api/users/auth/register`.
final class UserRegisterValidator extends Validator {
  UserRegisterValidator({
    required this.nickname,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    this.remember = false,
  });

  String nickname;
  String name;
  String email;

  /// Con código de país, ej. `+573001234567`.
  String phone;
  String password;
  bool remember;

  @override
  void prepareForValidation() {
    nickname = nickname.trim();
    name = Rules.collapseSpaces(name);
    email = email.trim().toLowerCase();
    phone = Rules.normalizePhone(phone);
  }

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    _profileRules(e, nickname: nickname, name: name, phone: phone, password: password);
    e.check('email', email.isNotEmpty, 'Escribe tu correo');
    e.check('email', Rules.isEmail(email), 'Escribe un correo válido');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {
        'nickname': nickname,
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'remember': remember,
      };
}

/// `POST /api/users/auth/login/google` — el ID token que dio Google Sign-In.
final class GoogleLoginValidator extends Validator {
  GoogleLoginValidator({required this.idToken, this.remember = false, this.method});

  String idToken;
  bool remember;
  TwoFactorMethod? method;

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('id_token', idToken.isNotEmpty, 'Vuelve a iniciar sesión con Google');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {
        'id_token': idToken,
        'remember': remember,
        if (method != null) 'method': method!.name,
      };
}

/// `POST /api/users/auth/register/google` — el email sale del ID token; el resto lo
/// llena el usuario (el nombre puede venir prellenado con el de Google).
final class GoogleRegisterValidator extends Validator {
  GoogleRegisterValidator({
    required this.idToken,
    required this.nickname,
    required this.name,
    required this.phone,
    required this.password,
    this.remember = false,
  });

  String idToken;
  String nickname;
  String name;
  String phone;
  String password;
  bool remember;

  @override
  void prepareForValidation() {
    nickname = nickname.trim();
    name = Rules.collapseSpaces(name);
    phone = Rules.normalizePhone(phone);
  }

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    _profileRules(e, nickname: nickname, name: name, phone: phone, password: password);
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {
        'id_token': idToken,
        'nickname': nickname,
        'name': name,
        'phone': phone,
        'password': password,
        'remember': remember,
      };
}

/// Reglas comunes del registro con email y con Google.
void _profileRules(
  FieldErrors e, {
  required String nickname,
  required String name,
  required String phone,
  required String password,
}) {
  e.check('name', name.isNotEmpty, 'Escribe tu nombre');
  e.check('name', Rules.isAlphaSpaces(name), 'Usa solo letras y espacios');
  e.check('name', Rules.length(name) >= 3, 'Escribe al menos 3 letras');
  e.check('name', Rules.length(name) <= 80, 'Usa máximo 80 caracteres');

  e.check('nickname', nickname.isNotEmpty, 'Elige un nombre de usuario');
  e.check(
    'nickname',
    Rules.isUsername(nickname, 3, 30),
    'De 3 a 30 caracteres. Empieza con una letra y usa letras, números, punto, guion o guion bajo',
  );

  e.check('phone', phone.isNotEmpty, 'Escribe tu teléfono');
  e.check('phone', Rules.isPhoneCode(phone), 'Incluye el código de país, ej. +57 300 123 4567');
  e.check('phone', Rules.knownPhoneCode(phone), 'El código de país no existe');

  e.check('password', password.isNotEmpty, 'Elige una contraseña');
  e.check('password', Rules.length(password) >= 8, 'Usa al menos 8 caracteres');
  e.check('password', Rules.length(password) <= 32, 'Usa máximo 32 caracteres');
}
