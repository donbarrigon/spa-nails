use ironforge::{Context, StrFormat, ValidationError, Validator};
use ironforge_macros::rules;
use serde::{Deserialize, Serialize};

use super::phone_codes::PHONE_CODES;

#[derive(Serialize, Deserialize)]
pub struct UserRegisterValidator {
    pub nickname: String,
    pub name: String,
    pub email: String,
    pub phone_code: String,
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
        Ok(())
    }

    fn validate(&mut self, c: &mut Context) -> Result<(), ValidationError> {
        rules! {
            self, c,
            nickname => [ required(), re_username(3, 30) ],
            name => [ required(), re_alpha_spaces(), min(3), max(80) ],
            email => [ required(), re_email() ],
            phone_code => [ required(), is_in(PHONE_CODES) ],
            phone => [ required(), re_phone() ],
            password => [ required(), min(8), max(32) ],
        }
    }
}

/// Token del enlace del email (64 caracteres hex).
#[derive(Serialize, Deserialize)]
pub struct VerifyEmailValidator {
    pub token: String,
}
impl Validator for VerifyEmailValidator {
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
pub struct VerifyPhoneValidator {
    pub code: String,
}
impl Validator for VerifyPhoneValidator {
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
