//! Mensajes de cuenta por WhatsApp: confirmar teléfono, recuperar contraseña y
//! código de segundo paso. Cada función crea el código en `tokens` y lo envía.
//!
//! Todo va como código de 6 dígitos: las plantillas de autenticación de Meta no
//! permiten enlaces. Al validarlos se usa `Token::consume_code` (filtra por usuario).

use std::time::Duration;

use ironforge::ForgeError;
use mongodb::bson::oid::ObjectId;
use serde_json::json;

use super::send_otp;
use crate::app::data::models::{
    token::{Token, TokenType},
    user::User,
};

const VERIFY_PHONE_MINUTES: u64 = 15;
const RESET_PASSWORD_MINUTES: u64 = 15;
const SECOND_FACTOR_MINUTES: u64 = 10;

/// En `data` va el teléfono al que se envió: al verificar hay que comprobar que
/// el usuario sigue teniendo ese teléfono.
pub async fn send_verify_phone(user: &User) -> Result<(), ForgeError> {
    let code = Token::issue_code(
        user_id(user)?,
        TokenType::VerifyPhone,
        Some(json!({ "phone_code": user.phone_code, "phone": user.phone })),
        Duration::from_secs(VERIFY_PHONE_MINUTES * 60),
    )
    .await?;

    send_otp(&user.phone_code, &user.phone, &code).await
}

/// Usa `ResetPasswordCode` y no `ResetPassword`: el de email se valida solo por
/// hash (sin usuario), y un código de 6 dígitos ahí se podría adivinar.
pub async fn send_reset_password(user: &User) -> Result<(), ForgeError> {
    let code = Token::issue_code(
        user_id(user)?,
        TokenType::ResetPasswordCode,
        None,
        Duration::from_secs(RESET_PASSWORD_MINUTES * 60),
    )
    .await?;

    send_otp(&user.phone_code, &user.phone, &code).await
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

    send_otp(&user.phone_code, &user.phone, &code).await
}

fn user_id(user: &User) -> Result<ObjectId, ForgeError> {
    user.id
        .ok_or_else(|| ForgeError::internal().message("Cannot send WhatsApp message to an unsaved user"))
}
