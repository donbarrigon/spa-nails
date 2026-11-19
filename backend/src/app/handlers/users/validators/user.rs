use ironforge::{Context, StrFormat, ValidationError, Validator, validator::format::Format};
use ironforge_macros::rules;
use serde::{Deserialize, Serialize};

use super::phone_codes::PHONE_CODES;
use crate::app::shared::models::user::TwoFactorMethod;

#[derive(Serialize, Deserialize)]
pub struct UserRegisterValidator {
    pub nickname: String,
    pub name: String,
    pub email: String,
    /// Con código de país, ej. `+573001234567`.
    pub phone: String,
    pub password: String,
    #[serde(default)]
    pub remember: bool,
}
impl Validator for UserRegisterValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.email = self.email.trim().to_lowercase();
        self.nickname = self.nickname.trim().to_string();
        self.name = self.name.trim().to_title_case_es();
        self.phone = normalize_phone(&self.phone);
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            nickname => [ required(), re_username(3, 30) ],
            name => [ required(), re_alpha_spaces(), min(3), max(80) ],
            email => [ required(), re_email() ],
            phone => [
                required(),
                re_phone_code(),
                known_phone_code().msg("the :field field has an unknown country code"),
            ],
            password => [ required(), min(8), max(32) ],
        }
    }
}

/// Token de un enlace enviado por email o WhatsApp (64 caracteres hex).
#[derive(Serialize, Deserialize)]
pub struct LinkTokenValidator {
    pub token: String,
}
impl Validator for LinkTokenValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.token = self.token.trim().to_string();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            token => [ required(), re_ex("token", r"^[0-9a-f]{64}$") ],
        }
    }
}

/// Código de 6 dígitos que llega por WhatsApp.
#[derive(Serialize, Deserialize)]
pub struct CodeValidator {
    pub code: String,
}
impl Validator for CodeValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.code = self.code.trim().to_string();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            code => [ required(), re_ex("code", r"^[0-9]{6}$") ],
        }
    }
}

/// Usuario (email o teléfono con código de país) y contraseña para iniciar sesión.
#[derive(Serialize, Deserialize)]
pub struct UserLoginValidator {
    pub user: String,
    pub password: String,
    #[serde(default)]
    pub remember: bool,
    /// Por dónde enviar el código si el usuario tiene segundo factor; si no
    /// viene, se usa el método preferido del usuario.
    #[serde(default)]
    pub method: Option<TwoFactorMethod>,
}

impl UserLoginValidator {
    pub fn is_email(&self) -> bool {
        self.user.contains('@')
    }
}

impl Validator for UserLoginValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.user = self.user.trim().to_lowercase();
        if !self.is_email() {
            self.user = normalize_phone(&self.user);
        }
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            user => [
                required().msg("Enter your email address or phone number"),
                email_or_phone().msg("Enter a valid email address or a phone number including the country code (e.g. +57)"),
            ],
            password => [
                required().msg("Enter your password"),
                // Mismo mensaje que credenciales incorrectas: no revela el formato.
                min(8).msg("The email, phone number or password is incorrect"),
                max(32).msg("The email, phone number or password is incorrect"),
            ],
        }
    }
}

/// Segundo paso del login: el `challenge` que devolvió `/api/users/auth/login` y el
/// código de 6 dígitos que llegó por email o WhatsApp.
#[derive(Serialize, Deserialize)]
pub struct LoginTwoFactorValidator {
    pub challenge: String,
    pub code: String,
}
impl Validator for LoginTwoFactorValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.challenge = self.challenge.trim().to_string();
        self.code = self.code.trim().to_string();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            challenge => [ required(), re_ex("token", r"^[0-9a-f]{64}$") ],
            code => [ required(), re_ex("code", r"^[0-9]{6}$") ],
        }
    }
}

/// Activa el segundo factor o cambia su método (`"email"`, `"whatsapp"` o `"totp"`).
/// Pide la contraseña: con solo una sesión robada no se puede cambiar.
#[derive(Serialize, Deserialize)]
pub struct TwoFactorValidator {
    pub method: TwoFactorMethod,
    pub password: String,
}
impl Validator for TwoFactorValidator {
    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            password => [ required().msg("Enter your password") ],
        }
    }
}

/// Solo la contraseña actual, para confirmar una acción sensible.
#[derive(Serialize, Deserialize)]
pub struct PasswordValidator {
    pub password: String,
}
impl Validator for PasswordValidator {
    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            password => [ required().msg("Enter your password") ],
        }
    }
}

/// Reenviar el código del segundo factor durante el login. `method` permite
/// cambiar de canal (ej. de email a WhatsApp); si no viene, se usa el del challenge.
#[derive(Serialize, Deserialize)]
pub struct ResendTwoFactorValidator {
    pub challenge: String,
    #[serde(default)]
    pub method: Option<TwoFactorMethod>,
}
impl Validator for ResendTwoFactorValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.challenge = self.challenge.trim().to_string();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            challenge => [ required(), re_ex("token", r"^[0-9a-f]{64}$") ],
        }
    }
}

/// Cambiar la contraseña con sesión: la actual y la nueva.
#[derive(Serialize, Deserialize)]
pub struct ChangePasswordValidator {
    pub current_password: String,
    pub password: String,
}
impl Validator for ChangePasswordValidator {
    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            current_password => [ required().msg("Enter your current password") ],
            password => [ required(), min(8), max(32) ],
        }
    }
}

/// Pedir la recuperación de contraseña: email o teléfono con código de país.
#[derive(Serialize, Deserialize)]
pub struct ForgotPasswordValidator {
    pub user: String,
}
impl ForgotPasswordValidator {
    pub fn is_email(&self) -> bool {
        self.user.contains('@')
    }
}
impl Validator for ForgotPasswordValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.user = self.user.trim().to_lowercase();
        if !self.is_email() {
            self.user = normalize_phone(&self.user);
        }
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            user => [
                required().msg("Enter your email address or phone number"),
                email_or_phone().msg("Enter a valid email address or a phone number including the country code (e.g. +57)"),
            ],
        }
    }
}

/// Nueva contraseña con el enlace que llegó por email.
#[derive(Serialize, Deserialize)]
pub struct ResetPasswordValidator {
    pub token: String,
    pub password: String,
}
impl Validator for ResetPasswordValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.token = self.token.trim().to_string();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            token => [ required(), re_ex("token", r"^[0-9a-f]{64}$") ],
            password => [ required(), min(8), max(32) ],
        }
    }
}

/// Nueva contraseña con el código que llegó por WhatsApp.
#[derive(Serialize, Deserialize)]
pub struct ResetPasswordCodeValidator {
    pub phone: String,
    pub code: String,
    pub password: String,
}
impl Validator for ResetPasswordCodeValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.phone = normalize_phone(&self.phone);
        self.code = self.code.trim().to_string();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            phone => [ required(), re_phone_code() ],
            code => [ required(), re_ex("code", r"^[0-9]{6}$") ],
            password => [ required(), min(8), max(32) ],
        }
    }
}

/// Pide cambiar el email. Exige la contraseña actual.
#[derive(Serialize, Deserialize)]
pub struct ChangeEmailValidator {
    pub email: String,
    pub password: String,
}
impl Validator for ChangeEmailValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.email = self.email.trim().to_lowercase();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            email => [ required(), re_email() ],
            password => [ required().msg("Enter your password") ],
        }
    }
}

/// Pide cambiar el teléfono (con código de país). Exige la contraseña actual.
#[derive(Serialize, Deserialize)]
pub struct ChangePhoneValidator {
    pub phone: String,
    pub password: String,
}
impl Validator for ChangePhoneValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.phone = normalize_phone(&self.phone);
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            phone => [
                required(),
                re_phone_code(),
                known_phone_code().msg("the :field field has an unknown country code"),
            ],
            password => [ required().msg("Enter your password") ],
        }
    }
}

// ===============================================================================
// Google
// ===============================================================================

/// ID token de Google: JWT de tres partes en base64url.
const ID_TOKEN_RE: &str = r"^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$";
/// Los de Google rondan 1-1.5 KB; el tope solo evita cuerpos enormes.
const ID_TOKEN_MAX: usize = 4096;

/// Login con Google: el ID token que dio `google_sign_in`.
#[derive(Serialize, Deserialize)]
pub struct GoogleLoginValidator {
    pub id_token: String,
    #[serde(default)]
    pub remember: bool,
    /// Igual que en el login con contraseña: por dónde enviar el código si el
    /// usuario tiene segundo factor.
    #[serde(default)]
    pub method: Option<TwoFactorMethod>,
}
impl Validator for GoogleLoginValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.id_token = self.id_token.trim().to_string();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            id_token => [ required(), max(ID_TOKEN_MAX), re_ex("id_token", ID_TOKEN_RE) ],
        }
    }
}

/// Registro con Google: el email sale del ID token; el resto lo llena el usuario
/// (el nombre puede venir prellenado con el de Google).
#[derive(Serialize, Deserialize)]
pub struct GoogleRegisterValidator {
    pub id_token: String,
    pub nickname: String,
    pub name: String,
    /// Con código de país, ej. `+573001234567`.
    pub phone: String,
    pub password: String,
    #[serde(default)]
    pub remember: bool,
}
impl Validator for GoogleRegisterValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.id_token = self.id_token.trim().to_string();
        self.nickname = self.nickname.trim().to_string();
        self.name = self.name.trim().to_title_case_es();
        self.phone = normalize_phone(&self.phone);
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            id_token => [ required(), max(ID_TOKEN_MAX), re_ex("id_token", ID_TOKEN_RE) ],
            nickname => [ required(), re_username(3, 30) ],
            name => [ required(), re_alpha_spaces(), min(3), max(80) ],
            phone => [
                required(),
                re_phone_code(),
                known_phone_code().msg("the :field field has an unknown country code"),
            ],
            password => [ required(), min(8), max(32) ],
        }
    }
}

/// Vincular Google desde el perfil. Exige la contraseña actual.
#[derive(Serialize, Deserialize)]
pub struct GoogleLinkValidator {
    pub id_token: String,
    pub password: String,
}
impl Validator for GoogleLinkValidator {
    fn prepare_for_validation(&mut self, _: &mut Context) -> Result<(), ValidationError> {
        self.id_token = self.id_token.trim().to_string();
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            id_token => [ required(), max(ID_TOKEN_MAX), re_ex("id_token", ID_TOKEN_RE) ],
            password => [ required().msg("Enter your password") ],
        }
    }
}

// ===============================================================================
// Teléfono
// ===============================================================================

/// Quita espacios y separadores (`-`, `.`, `(`, `)`) y cambia el prefijo
/// internacional `00` por `+`: `0057 300-123 4567` → `+573001234567`.
fn normalize_phone(phone: &str) -> String {
    let phone: String = phone
        .chars()
        .filter(|c| !c.is_whitespace() && !matches!(c, '-' | '.' | '(' | ')'))
        .collect();
    match phone.strip_prefix("00") {
        Some(rest) => format!("+{rest}"),
        None => phone,
    }
}

/// Reglas propias para `rules!` (se llaman como método del campo).
trait UserRules {
    /// Empieza con un código de país de `PHONE_CODES`.
    fn known_phone_code(&self) -> bool;
    /// Email válido, o teléfono con código de país conocido.
    fn email_or_phone(&self) -> bool;
}

impl UserRules for str {
    fn known_phone_code(&self) -> bool {
        PHONE_CODES.iter().any(|code| self.starts_with(code))
    }

    fn email_or_phone(&self) -> bool {
        if self.contains('@') {
            self.re_email()
        } else {
            self.re_phone_code() && self.known_phone_code()
        }
    }
}
