use ironforge::{Context, ForgeError, ODModel, log, session};
use mongodb::bson::{DateTime, doc};
use serde_json::json;

use crate::app::{
    data::{
        models::{
            history::{
                ActionType::{Create, Update},
                History,
            },
            token::{Token, TokenType},
            user::User,
        },
        resources::session_user::SessionUser,
    },
    handler::{
        services::{mailer, whatsapp},
        validators::user::{UserRegisterValidator, VerifyEmailValidator, VerifyPhoneValidator},
    },
};

pub async fn register(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<UserRegisterValidator>().await?;

    let remember = req.remember;
    let mut user = User::fill_register(req);

    user.create().await?;
    let su = SessionUser::try_from(&user)?;
    let auth = c.login(su, remember).await?;

    let verify_user = user.clone();
    tokio::spawn(async move {
        if let Err(e) = mailer::account::send_verify_email(&verify_user).await {
            log::error(
                "Failed to send verify email",
                Some(
                    json!({ "fn": "user::register", "user_id": verify_user.id, "error": e.to_string() }),
                ),
            );
        }
        if let Err(e) = whatsapp::account::send_verify_phone(&verify_user).await {
            log::error(
                "Failed to send verify phone",
                Some(
                    json!({ "fn": "user::register", "user_id": verify_user.id, "error": e.to_string() }),
                ),
            );
        }
    });

    History::record(c, user, None, Create, Some("User register")).await;

    c.response_created(&*auth.user)
}

/// `POST /api/users/verify/email` — body `{ "token": "..." }` (el del enlace del email).
///
/// No exige sesión: el enlace se puede abrir en otro navegador o dispositivo.
/// El token (32 bytes aleatorios) es la prueba de que es el dueño del email.
pub async fn verify_email(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<VerifyEmailValidator>().await?;

    let token = Token::consume_link(TokenType::VerifyEmail, &req.token).await?;
    let mut user = User::get_by_id(token.user_id).await?;

    // El enlace es para el email al que se envió; si el usuario lo cambió, ya no sirve.
    if token.data_field("email") != Some(user.email.as_str()) {
        return Err(ForgeError::gone().message("Email changed, request a new verification link"));
    }

    if user.email_verified_at.is_none() {
        user.update_fields(doc! { "email_verified_at": DateTime::now() }).await?;
        session()?.refresh_user(SessionUser::try_from(&user)?).await?;

        // `History::record` necesita sesión: solo se registra si abrió el enlace logueado.
        if c.try_auth::<SessionUser>().await?.is_some() {
            let old = json!({ "email_verified_at": null });
            History::record(c, user, Some(old), Update, Some("User verify email")).await;
        }
    }

    c.response_no_content()
}

/// `POST /api/users/verify/phone` — body `{ "code": "123456" }` (el que llega por WhatsApp).
///
/// Exige sesión: el código son 6 dígitos y solo es válido junto al usuario.
/// Responde el usuario de la sesión actualizado para que la app no tenga que pedirlo.
pub async fn verify_phone(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<VerifyPhoneValidator>().await?;

    let token = Token::consume_code(auth.user_id, TokenType::VerifyPhone, &req.code).await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    // El código es para el teléfono al que se envió; si el usuario lo cambió, ya no sirve.
    if token.data_field("phone_code") != Some(user.phone_code.as_str())
        || token.data_field("phone") != Some(user.phone.as_str())
    {
        return Err(ForgeError::gone().message("Phone changed, request a new verification code"));
    }

    if user.phone_verified_at.is_none() {
        user.update_fields(doc! { "phone_verified_at": DateTime::now() }).await?;
        session()?.refresh_user(SessionUser::try_from(&user)?).await?;

        let old = json!({ "phone_verified_at": null });
        History::record(c, user.clone(), Some(old), Update, Some("User verify phone")).await;
    }

    c.response_ok(&SessionUser::try_from(&user)?)
}

pub async fn loggin(_: &mut Context) -> Result<(), ForgeError> {
    Ok(())
}
