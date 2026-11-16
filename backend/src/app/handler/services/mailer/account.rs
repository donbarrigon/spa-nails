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
pub const CHANGE_EMAIL_PATH: &str = "/confirm-email-change";
pub const REVERT_EMAIL_PATH: &str = "/revert-email";
/// Página para pedir el enlace o código de recuperación (va en los avisos de seguridad).
pub const FORGOT_PASSWORD_PATH: &str = "/forgot-password";

const VERIFY_EMAIL_HOURS: u64 = 24;
const RESET_PASSWORD_MINUTES: u64 = 60;
const SECOND_FACTOR_MINUTES: u64 = 10;
const CHANGE_EMAIL_HOURS: u64 = 24;
/// Igual para email y teléfono: tiempo para deshacer un cambio.
pub const REVERT_CHANGE_DAYS: u64 = 7;

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

/// En `data` va el email al que se envió: si el usuario lo cambia, el enlace ya no sirve.
pub async fn send_reset_password(user: &User) -> Result<(), ForgeError> {
    let token = Token::issue_link(
        user_id(user)?,
        TokenType::ResetPassword,
        Some(json!({ "email": user.email })),
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

/// Al email nuevo (`pending_email`). En `data` va ese email: al confirmar hay
/// que comprobar que sigue siendo el pendiente.
pub async fn send_change_email(user: &User) -> Result<(), ForgeError> {
    let new_email = user
        .pending_email
        .as_deref()
        .ok_or_else(|| ForgeError::internal().message("User has no pending email"))?;
    let token = Token::issue_link(
        user_id(user)?,
        TokenType::ChangeEmail,
        Some(json!({ "email": new_email })),
        Duration::from_secs(CHANGE_EMAIL_HOURS * 3600),
    )
    .await?;

    let email = templates::change_email(&user.nickname, &link(CHANGE_EMAIL_PATH, &token), CHANGE_EMAIL_HOURS);
    send(&user.nickname, new_email, email).await
}

/// Al email anterior, después del cambio. En `data` va ese email: al deshacer
/// vuelve a ser el de la cuenta.
pub async fn send_email_changed(user: &User, old_email: &str) -> Result<(), ForgeError> {
    let token = Token::issue_extra_link(
        user_id(user)?,
        TokenType::RevertEmail,
        Some(json!({ "email": old_email })),
        Duration::from_secs(REVERT_CHANGE_DAYS * 24 * 3600),
    )
    .await?;

    let email = templates::email_changed(
        &user.nickname,
        &user.email,
        &link(REVERT_EMAIL_PATH, &token),
        REVERT_CHANGE_DAYS,
    );
    send(&user.nickname, old_email, email).await
}

/// Aviso de seguridad: se cambió la contraseña (con sesión o por recuperación).
/// Solo a un email verificado.
pub async fn send_password_changed(user: &User) -> Result<(), ForgeError> {
    if user.email_verified_at.is_none() {
        return Ok(());
    }
    let email = templates::password_changed(&user.nickname, &forgot_link());
    send(&user.nickname, &user.email, email).await
}

/// Aviso de seguridad: se desactivó la segunda verificación. Solo a un email verificado.
pub async fn send_two_factor_disabled(user: &User) -> Result<(), ForgeError> {
    if user.email_verified_at.is_none() {
        return Ok(());
    }
    let email = templates::two_factor_disabled(&user.nickname, &forgot_link());
    send(&user.nickname, &user.email, email).await
}

fn forgot_link() -> String {
    format!("{}{FORGOT_PASSWORD_PATH}", env().app.url.trim_end_matches('/'))
}

fn user_id(user: &User) -> Result<ObjectId, ForgeError> {
    user.id
        .ok_or_else(|| ForgeError::internal().message("Cannot send account email to an unsaved user"))
}

fn link(path: &str, token: &str) -> String {
    format!("{}{path}?token={token}", env().app.url.trim_end_matches('/'))
}
