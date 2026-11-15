//! Emails de cuenta: verificar email, restablecer contraseña y segunda verificación.
//! Cada función crea el token en `tokens` y envía el correo.

use std::time::Duration;

use ironforge::{ForgeError, env};
use mongodb::bson::oid::ObjectId;
use serde_json::json;

use super::{send, templates};
use crate::app::data::models::{
    token::{Token, TokenType},
    user::User,
};

/// Rutas del front a las que apuntan los enlaces (`{app.url}{ruta}?token=...`).
pub const VERIFY_EMAIL_PATH: &str = "/verify-email";
pub const RESET_PASSWORD_PATH: &str = "/reset-password";

const VERIFY_EMAIL_HOURS: u64 = 24;
const RESET_PASSWORD_MINUTES: u64 = 60;
const SECOND_FACTOR_MINUTES: u64 = 10;

/// En `data` va el email al que se envió: al verificar hay que comprobar que
/// el usuario sigue teniendo ese email.
pub async fn send_verify_email(user: &User) -> Result<(), ForgeError> {
    let token = Token::issue_link(
        user_id(user)?,
        TokenType::VerifyEmail,
        Some(json!({ "email": user.email })),
        Duration::from_secs(VERIFY_EMAIL_HOURS * 3600),
    )
    .await?;

    let email = templates::verify_email(&user.nickname, &link(VERIFY_EMAIL_PATH, &token), VERIFY_EMAIL_HOURS);
    send(&user.nickname, &user.email, email).await
}

pub async fn send_reset_password(user: &User) -> Result<(), ForgeError> {
    let token = Token::issue_link(
        user_id(user)?,
        TokenType::ResetPassword,
        None,
        Duration::from_secs(RESET_PASSWORD_MINUTES * 60),
    )
    .await?;

    let email = templates::reset_password(&user.nickname, &link(RESET_PASSWORD_PATH, &token), RESET_PASSWORD_MINUTES);
    send(&user.nickname, &user.email, email).await
}

pub async fn send_second_factor(user: &User) -> Result<(), ForgeError> {
    let code = Token::issue_code(
        user_id(user)?,
        TokenType::SecondFactor,
        None,
        Duration::from_secs(SECOND_FACTOR_MINUTES * 60),
    )
    .await?;

    let email = templates::second_factor(&user.nickname, &code, SECOND_FACTOR_MINUTES);
    send(&user.nickname, &user.email, email).await
}

fn user_id(user: &User) -> Result<ObjectId, ForgeError> {
    user.id
        .ok_or_else(|| ForgeError::internal().message("Cannot send account email to an unsaved user"))
}

fn link(path: &str, token: &str) -> String {
    format!("{}{path}?token={token}", env().app.url.trim_end_matches('/'))
}
