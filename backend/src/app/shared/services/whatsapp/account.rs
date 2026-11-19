//! Mensajes de cuenta por WhatsApp: confirmar teléfono, recuperar contraseña y
//! código de segundo paso. Cada función crea el código en `tokens` y lo envía.
//!
//! Todo va como código de 6 dígitos: las plantillas de autenticación de Meta no
//! permiten enlaces. Al validarlos se usa `Token::consume_code` (filtra por usuario).

use std::time::Duration;

use ironforge::ForgeError;
use mongodb::bson::oid::ObjectId;
use serde_json::json;

use super::{send_otp, send_phone_changed};
use crate::app::shared::services::mailer::account::REVERT_CHANGE_DAYS;
use crate::app::handlers::users::validators::phone_codes::PHONE_CODES;
use crate::app::shared::models::{
    token::{Token, TokenType},
    user::User,
};

const VERIFY_PHONE_MINUTES: u64 = 15;
const RESET_PASSWORD_MINUTES: u64 = 15;
const SECOND_FACTOR_MINUTES: u64 = 10;
const CHANGE_PHONE_MINUTES: u64 = 15;

/// En `data` va el teléfono al que se envió: al verificar hay que comprobar que
/// el usuario sigue teniendo ese teléfono.
pub async fn send_verify_phone(user: &User) -> Result<(), ForgeError> {
    let code = Token::issue_code(
        user_id(user)?,
        TokenType::VerifyPhone,
        Some(json!({ "phone": user.phone })),
        Duration::from_secs(VERIFY_PHONE_MINUTES * 60),
    )
    .await?;

    send_otp(&user.phone, &code).await
}

/// Usa `ResetPasswordCode` y no `ResetPassword`: el de email se valida solo por
/// hash (sin usuario), y un código de 6 dígitos ahí se podría adivinar.
/// En `data` va el teléfono al que se envió: si el usuario lo cambia, el código ya no sirve.
pub async fn send_reset_password(user: &User) -> Result<(), ForgeError> {
    let code = Token::issue_code(
        user_id(user)?,
        TokenType::ResetPasswordCode,
        Some(json!({ "phone": user.phone })),
        Duration::from_secs(RESET_PASSWORD_MINUTES * 60),
    )
    .await?;

    send_otp(&user.phone, &code).await
}

/// Mismo `TokenType::SecondFactor` que el email: pedir el código por un canal
/// invalida el enviado por el otro.
pub async fn send_second_factor(user: &User) -> Result<(), ForgeError> {
    let code = Token::issue_code(
        user_id(user)?,
        TokenType::SecondFactor,
        None,
        Duration::from_secs(SECOND_FACTOR_MINUTES * 60),
    )
    .await?;

    send_otp(&user.phone, &code).await
}

/// Código al teléfono nuevo (`pending_phone`). En `data` va ese teléfono: al
/// confirmar hay que comprobar que sigue siendo el pendiente.
pub async fn send_change_phone(user: &User) -> Result<(), ForgeError> {
    let new_phone = user
        .pending_phone
        .as_deref()
        .ok_or_else(|| ForgeError::internal().message("User has no pending phone"))?;
    let code = Token::issue_code(
        user_id(user)?,
        TokenType::ChangePhone,
        Some(json!({ "phone": new_phone })),
        Duration::from_secs(CHANGE_PHONE_MINUTES * 60),
    )
    .await?;

    send_otp(new_phone, &code).await
}

/// Al teléfono anterior, después del cambio. En `data` va ese teléfono: al
/// deshacer vuelve a ser el de la cuenta.
pub async fn send_phone_changed_notice(user: &User, old_phone: &str) -> Result<(), ForgeError> {
    let token = Token::issue_extra_link(
        user_id(user)?,
        TokenType::RevertPhone,
        Some(json!({ "phone": old_phone })),
        Duration::from_secs(REVERT_CHANGE_DAYS * 24 * 3600),
    )
    .await?;

    send_phone_changed(old_phone, &mask_phone(&user.phone), &token).await
}

/// Deja visibles el código de país y los últimos 4 dígitos: `+573001234567` → `+57******4567`.
/// El código de país se toma de `PHONE_CODES`, que no tiene prefijos ambiguos.
fn mask_phone(phone: &str) -> String {
    let code = PHONE_CODES
        .iter()
        .find(|code| phone.starts_with(*code))
        .copied()
        .unwrap_or("+");
    let number = &phone[code.len()..];
    let visible = number.len().saturating_sub(4);
    format!("{code}{}{}", "*".repeat(visible), &number[visible..])
}

fn user_id(user: &User) -> Result<ObjectId, ForgeError> {
    user.id
        .ok_or_else(|| ForgeError::internal().message("Cannot send WhatsApp message to an unsaved user"))
}

#[cfg(test)]
mod tests {
    use super::mask_phone;

    #[test]
    fn mask_phone_deja_codigo_y_ultimos_4() {
        assert_eq!(mask_phone("+573001234567"), "+57******4567");
        assert_eq!(mask_phone("+12025550123"), "+1******0123");
        assert_eq!(mask_phone("+593991234567"), "+593*****4567");
    }
}
