import '../models/two_factor.dart';
import 'rules.dart';
import 'validator.dart';

// Espejo de `backend/src/app/handlers/users/validators/user.rs`: mismos nombres, campos
// y reglas. Si una regla cambia allá, cambia acá.
//
// Única excepción: `passwordConfirmation` (repetir la contraseña nueva) solo existe
// aquí. Se valida en web y mobile y no se envía: el backend no la conoce.

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
    required this.passwordConfirmation,
    this.remember = false,
  });

  String nickname;
  String name;
  String email;

  /// Con código de país, ej. `+573001234567`.
  String phone;
  String password;

  /// Solo en el cliente: no va en [toJson].
  String passwordConfirmation;
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
    _confirmationRules(e, password, passwordConfirmation);
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

/// `POST /api/users/auth/register/available` — revisa si un campo del registro
/// ([field]: `nickname`, `email` o `phone`) ya está en uso, cuando el usuario sale
/// de él. Solo se envía si el formato es válido.
final class RegisterAvailableValidator extends Validator {
  RegisterAvailableValidator({required this.field, required this.value});

  final String field;
  String value;

  @override
  void prepareForValidation() {
    value = switch (field) {
      'email' => value.trim().toLowerCase(),
      'phone' => Rules.normalizePhone(value),
      _ => value.trim(),
    };
  }

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    final valid = switch (field) {
      'nickname' => Rules.isUsername(value, 3, 30),
      'email' => Rules.isEmail(value),
      'phone' => Rules.isPhoneCode(value) && Rules.knownPhoneCode(value),
      _ => false,
    };
    // Sin mensaje propio: el formato lo explica el registro al enviarlo.
    e.check(field, valid, 'Formato no válido');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {field: value};
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
    required this.passwordConfirmation,
    this.remember = false,
  });

  String idToken;
  String nickname;
  String name;
  String phone;
  String password;

  /// Solo en el cliente: no va en [toJson].
  String passwordConfirmation;
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
    _confirmationRules(e, password, passwordConfirmation);
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

// ===============================================================================
// Recuperar contraseña (sin sesión)
// ===============================================================================

/// `POST /api/users/auth/password/forgot` — `user` es el email (llega un enlace)
/// o el teléfono con código de país (llega un código por WhatsApp).
final class ForgotPasswordValidator extends Validator {
  ForgotPasswordValidator({required this.user});

  String user;

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
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'user': user};
}

/// `POST /api/users/auth/password/reset` — el token del enlace del email.
final class ResetPasswordValidator extends Validator {
  ResetPasswordValidator({required this.token, required this.password, required this.passwordConfirmation});

  String token;
  String password;

  /// Solo en el cliente: no va en [toJson].
  String passwordConfirmation;

  @override
  void prepareForValidation() => token = token.trim();

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    _newPasswordRules(e, password);
    _confirmationRules(e, password, passwordConfirmation);
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'token': token, 'password': password};
}

/// `POST /api/users/auth/password/reset/code` — el código que llegó por WhatsApp.
final class ResetPasswordCodeValidator extends Validator {
  ResetPasswordCodeValidator({
    required this.phone,
    required this.code,
    required this.password,
    required this.passwordConfirmation,
  });

  String phone;
  String code;
  String password;

  /// Solo en el cliente: no va en [toJson].
  String passwordConfirmation;

  @override
  void prepareForValidation() {
    phone = Rules.normalizePhone(phone);
    code = code.replaceAll(RegExp(r'\s'), '');
  }

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('code', code.isNotEmpty, 'Escribe el código');
    e.check('code', Rules.isCode(code), 'El código tiene 6 dígitos');
    _newPasswordRules(e, password);
    _confirmationRules(e, password, passwordConfirmation);
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'phone': phone, 'code': code, 'password': password};
}

/// La contraseña repetida (`password_confirmation`) debe ser igual a la nueva.
void _confirmationRules(FieldErrors e, String password, String confirmation) {
  e.check('password_confirmation', confirmation.isNotEmpty, 'Repite la contraseña');
  e.check('password_confirmation', confirmation == password, 'Las contraseñas no coinciden');
}

void _newPasswordRules(FieldErrors e, String password) {
  e.check('password', password.isNotEmpty, 'Elige una contraseña nueva');
  e.check('password', Rules.length(password) >= 8, 'Usa al menos 8 caracteres');
  e.check('password', Rules.length(password) <= 32, 'Usa máximo 32 caracteres');
}

// ===============================================================================
// Cuenta (con sesión)
// ===============================================================================

/// `PUT /api/users/auth/email` — el correo nuevo queda pendiente hasta confirmarlo.
final class ChangeEmailValidator extends Validator {
  ChangeEmailValidator({required this.email, required this.password});

  String email;
  String password;

  @override
  void prepareForValidation() => email = email.trim().toLowerCase();

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('email', email.isNotEmpty, 'Escribe el correo nuevo');
    e.check('email', Rules.isEmail(email), 'Escribe un correo válido');
    e.check('password', password.isNotEmpty, 'Escribe tu contraseña');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'email': email, 'password': password};
}

/// `PUT /api/users/auth/phone` — el teléfono nuevo queda pendiente hasta
/// confirmarlo con el código que llega por WhatsApp.
final class ChangePhoneValidator extends Validator {
  ChangePhoneValidator({required this.phone, required this.password});

  String phone;
  String password;

  @override
  void prepareForValidation() => phone = Rules.normalizePhone(phone);

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('phone', phone.isNotEmpty, 'Escribe el teléfono nuevo');
    e.check('phone', Rules.isPhoneCode(phone), 'Incluye el código de país, ej. +57 300 123 4567');
    e.check('phone', Rules.knownPhoneCode(phone), 'El código de país no existe');
    e.check('password', password.isNotEmpty, 'Escribe tu contraseña');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'phone': phone, 'password': password};
}

/// `PUT /api/users/auth/password`.
final class ChangePasswordValidator extends Validator {
  ChangePasswordValidator({
    required this.currentPassword,
    required this.password,
    required this.passwordConfirmation,
  });

  String currentPassword;
  String password;

  /// Solo en el cliente: no va en [toJson].
  String passwordConfirmation;

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('current_password', currentPassword.isNotEmpty, 'Escribe tu contraseña actual');
    e.check('password', password.isNotEmpty, 'Elige una contraseña nueva');
    e.check('password', Rules.length(password) >= 8, 'Usa al menos 8 caracteres');
    e.check('password', Rules.length(password) <= 32, 'Usa máximo 32 caracteres');
    _confirmationRules(e, password, passwordConfirmation);
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'current_password': currentPassword, 'password': password};
}

/// Solo la contraseña, para confirmar una acción sensible (desactivar la
/// verificación en dos pasos, configurar la app de autenticación).
final class PasswordValidator extends Validator {
  PasswordValidator({required this.password});

  String password;

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('password', password.isNotEmpty, 'Escribe tu contraseña');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'password': password};
}

/// `PUT /api/users/auth/two-factor` — activa o cambia el método.
final class TwoFactorValidator extends Validator {
  TwoFactorValidator({required this.method, required this.password});

  TwoFactorMethod method;
  String password;

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('password', password.isNotEmpty, 'Escribe tu contraseña');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'method': method.name, 'password': password};
}

/// Código de 6 dígitos que llegó por WhatsApp o que muestra la app de autenticación.
final class CodeValidator extends Validator {
  CodeValidator({required this.code});

  String code;

  @override
  void prepareForValidation() => code = code.replaceAll(RegExp(r'\s'), '');

  @override
  Map<String, String> validate() {
    final e = FieldErrors();
    e.check('code', code.isNotEmpty, 'Escribe el código');
    e.check('code', Rules.isCode(code), 'El código tiene 6 dígitos');
    return e.errors;
  }

  @override
  Map<String, Object?> toJson() => {'code': code};
}
