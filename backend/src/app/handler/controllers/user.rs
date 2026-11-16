use std::{net::IpAddr, time::Duration};

use ironforge::{Context, ForgeError, ODModel, log, session};
use mongodb::bson::{DateTime, doc, oid::ObjectId};
use serde_json::json;

use crate::app::{
    data::{
        models::{
            history::{
                ActionType::{Create, Delete, Update},
                History,
            },
            throttle::{Limit, Throttle},
            token::{Token, TokenType},
            user::{TwoFactorMethod, User},
        },
        resources::session_user::SessionUser,
    },
    handler::{
        services::{mailer, totp, whatsapp},
        validators::user::{
            ChangeEmailValidator, ChangePasswordValidator, ChangePhoneValidator, CodeValidator,
            ForgotPasswordValidator, LinkTokenValidator, LoginTwoFactorValidator, PasswordValidator,
            ResendTwoFactorValidator, ResetPasswordCodeValidator, ResetPasswordValidator,
            TwoFactorValidator, UserLoginValidator, UserRegisterValidator,
        },
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
    let req = c.get_body::<LinkTokenValidator>().await?;

    let token = Token::consume_link(TokenType::VerifyEmail, &req.token).await?;
    let mut user = User::get_by_id(token.user_id).await?;

    // El enlace es para el email al que se envió; si el usuario lo cambió, ya no sirve.
    if token.data_field("email") != Some(user.email.as_str()) {
        return Err(ForgeError::gone().message("Email changed, request a new verification link"));
    }

    if user.email_verified_at.is_none() {
        user.update_fields(doc! { "email_verified_at": DateTime::now() }).await?;
        session()?.refresh_user(SessionUser::try_from(&user)?).await?;

        // Sin depender de la sesión: la acción la hizo el dueño del enlace.
        let old = json!({ "email_verified_at": null });
        History::record_with_user(token.user_id, user, Some(old), Update, Some("User verify email"))
            .await;
    }

    c.response_no_content()
}

/// `POST /api/users/verify/phone` — body `{ "code": "123456" }` (el que llega por WhatsApp).
///
/// Exige sesión: el código son 6 dígitos y solo es válido junto al usuario.
/// Responde el usuario de la sesión actualizado para que la app no tenga que pedirlo.
pub async fn verify_phone(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<CodeValidator>().await?;

    let token = Token::consume_code(auth.user_id, TokenType::VerifyPhone, &req.code).await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    // El código es para el teléfono al que se envió; si el usuario lo cambió, ya no sirve.
    if token.data_field("phone") != Some(user.phone.as_str()) {
        return Err(ForgeError::gone().message("Phone changed, request a new verification code"));
    }

    if user.phone_verified_at.is_none() {
        user.update_fields(doc! { "phone_verified_at": DateTime::now() }).await?;
        session()?.refresh_user(SessionUser::try_from(&user)?).await?;

        let old = json!({ "phone_verified_at": null });
        History::record_with_user(
            token.user_id,
            user.clone(),
            Some(old),
            Update,
            Some("User verify phone"),
        )
        .await;
    }

    c.response_ok(&SessionUser::try_from(&user)?)
}

/// Mismo tiempo que el código `SecondFactor` que se envía con él.
const LOGIN_CHALLENGE_MINUTES: u64 = 10;

/// Mismo mensaje para usuario inexistente, borrado o contraseña incorrecta:
/// no revela cuál de los tres falló.
const INVALID_CREDENTIALS: &str = "The email, phone number or password is incorrect";

/// `POST /api/users/login` — body `{ "user", "password", "remember", "method"? }`.
///
/// `user` es el email o el teléfono con código de país.
/// - Sin segundo factor: inicia sesión y responde `200` con el usuario.
/// - Con segundo factor: usa `method` (o el preferido del usuario si no viene)
///   y responde `202` con `{ "challenge", "method", "expires_in" }`. Con email o
///   WhatsApp envía el código; con `totp` el código lo da la app de autenticación.
///   La sesión se crea en `POST /api/users/login/two-factor`.
pub async fn login(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<UserLoginValidator>().await?;

    let filter = if req.is_email() {
        doc! { "email": &req.user }
    } else {
        doc! { "phone": &req.user }
    };
    let found = User::find::<User>(filter)?.limit(1).get().await?.pop();

    // El límite cuenta por cuenta (o por lo escrito, si no existe: así se bloquea
    // igual y no revela si existe) y por IP.
    let account = match &found {
        Some(user) => id_of(user)?.to_hex(),
        None => req.user.clone(),
    };
    let limits = password_limits(c.ip(), &account);
    Throttle::check(&limits).await?;

    let valid = match &found {
        Some(user) => user.check_password(req.password.clone()).await? && user.deleted_at.is_none(),
        None => {
            User::check_password_dummy(req.password.clone()).await?;
            false
        }
    };
    let (true, Some(mut user)) = (valid, found) else {
        Throttle::hit(&limits).await?;
        return Err(ForgeError::unauthorized().message(INVALID_CREDENTIALS));
    };
    Throttle::clear(&limits[0].key).await;

    if user.needs_rehash() {
        user.password = req.password;
        user.hash_password().await?;
        let password = user.password.clone();
        user.update_fields(doc! { "password": password }).await?;
    }

    let Some(preferred) = user.two_factor else {
        let auth = c.login(SessionUser::try_from(&user)?, req.remember).await?;
        return c.response_ok(&*auth.user);
    };

    // El método elegido en este login tiene prioridad sobre el preferido.
    let method = req.method.unwrap_or(preferred);
    if !user.can_use_two_factor(method) {
        return Err(ForgeError::unprocessable_entity()
            .message("The selected verification method is not available on this account"));
    }

    let challenge = Token::issue_link(
        id_of(&user)?,
        TokenType::LoginChallenge,
        Some(json!({ "remember": req.remember, "method": method })),
        Duration::from_secs(LOGIN_CHALLENGE_MINUTES * 60),
    )
    .await?;

    match method {
        TwoFactorMethod::Email => mailer::account::send_second_factor(&user).await?,
        TwoFactorMethod::Whatsapp => whatsapp::account::send_second_factor(&user).await?,
        TwoFactorMethod::Totp => {}
    }

    c.response_accepted(&json!({
        "challenge": challenge,
        "method": method,
        "expires_in": LOGIN_CHALLENGE_MINUTES * 60,
    }))
}

/// `POST /api/users/login/two-factor` — body `{ "challenge", "code" }`.
///
/// Segundo paso del login: valida el código (enviado por email/WhatsApp o de la
/// app de autenticación, según el método del primer paso) y crea la sesión.
/// Admite pocos intentos (`MAX_CODE_ATTEMPTS`); agotados hay que volver a `/users/login`.
pub async fn login_two_factor(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<LoginTwoFactorValidator>().await?;

    let challenge = Token::find_link(TokenType::LoginChallenge, &req.challenge)
        .await
        .map_err(|_| ForgeError::unauthorized().message("Your sign-in session expired, sign in again"))?;

    let mut user = User::get_by_id(challenge.user_id).await?;
    if user.deleted_at.is_some() {
        return Err(ForgeError::unauthorized().message(INVALID_CREDENTIALS));
    }

    let method = challenge
        .data
        .as_ref()
        .and_then(|d| d.get("method"))
        .and_then(|m| serde_json::from_value::<TwoFactorMethod>(m.clone()).ok());
    if method == Some(TwoFactorMethod::Totp) {
        // El TOTP no vive en `tokens`: los intentos se cuentan sobre el challenge.
        challenge.count_attempt().await?;
        totp::verify(&mut user, &req.code).await?;
    } else {
        Token::consume_code(challenge.user_id, TokenType::SecondFactor, &req.code).await?;
    }

    // Se gasta al final: así un código mal escrito no obliga a repetir la contraseña.
    // Si dos requests correctos llegan a la vez, solo el que lo borra inicia sesión.
    Token::consume_link(TokenType::LoginChallenge, &req.challenge)
        .await
        .map_err(|_| ForgeError::unauthorized().message("Your sign-in session expired, sign in again"))?;

    let remember = challenge
        .data
        .as_ref()
        .and_then(|d| d.get("remember"))
        .and_then(|r| r.as_bool())
        .unwrap_or(false);
    let auth = c.login(SessionUser::try_from(&user)?, remember).await?;
    c.response_ok(&*auth.user)
}

/// Reenvíos permitidos por challenge: cada código nuevo trae sus propios intentos,
/// así que sin tope se podría adivinar pidiendo códigos sin fin.
const MAX_TWO_FACTOR_RESENDS: u64 = 3;

/// `POST /api/users/login/two-factor/resend` — body `{ "challenge", "method"? }`.
///
/// Reenvía el código del segundo factor sin repetir la contraseña. Con `method`
/// cambia de canal (ej. de email a WhatsApp, o a la app de autenticación, que
/// no envía nada). Responde `202` con `{ "challenge", "method" }`.
pub async fn resend_two_factor(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<ResendTwoFactorValidator>().await?;

    let challenge = Token::find_link(TokenType::LoginChallenge, &req.challenge)
        .await
        .map_err(|_| ForgeError::unauthorized().message("Your sign-in session expired, sign in again"))?;
    let user = User::get_by_id(challenge.user_id).await?;
    if user.deleted_at.is_some() {
        return Err(ForgeError::unauthorized().message(INVALID_CREDENTIALS));
    }

    let data = challenge.data.clone().unwrap_or_default();
    let current = serde_json::from_value::<TwoFactorMethod>(data["method"].clone()).ok();
    let Some(method) = req.method.or(current) else {
        return Err(ForgeError::unprocessable_entity().message("Choose a verification method"));
    };
    if !user.can_use_two_factor(method) {
        return Err(ForgeError::unprocessable_entity()
            .message("The selected verification method is not available on this account"));
    }

    // Se cuenta y se cambia el método con un update condicionado: con requests en
    // paralelo no se pasa del tope.
    let method_bson = mongodb::bson::to_bson(&method)
        .map_err(|e| ForgeError::internal().caused_by(e).message("Invalid two-factor method"))?;
    let res = Token::coll()?
        .update_one(
            doc! {
                "_id": challenge.id,
                "$or": [
                    { "data.resends": { "$exists": false } },
                    { "data.resends": { "$lt": MAX_TWO_FACTOR_RESENDS as i64 } },
                ],
            },
            doc! { "$set": { "data.method": method_bson }, "$inc": { "data.resends": 1_i64 } },
        )
        .await
        .map_err(|e| ForgeError::internal().caused_by(e).message("Failed to update sign-in session"))?;
    if res.matched_count == 0 {
        return Err(ForgeError::too_many_requests().message("Too many codes requested, sign in again"));
    }

    match method {
        TwoFactorMethod::Email => mailer::account::send_second_factor(&user).await?,
        TwoFactorMethod::Whatsapp => whatsapp::account::send_second_factor(&user).await?,
        TwoFactorMethod::Totp => {}
    }

    c.response_accepted(&json!({ "challenge": req.challenge, "method": method }))
}

/// `PUT /api/users/two-factor` — body `{ "method": "email" | "whatsapp" | "totp", "password" }`.
///
/// Exige sesión. Activa el segundo factor o cambia el método preferido para el
/// login. Solo se acepta un canal ya verificado o la app de autenticación ya
/// confirmada. Para desactivarlo: `DELETE /api/users/two-factor`.
/// Responde el usuario de la sesión actualizado.
pub async fn update_two_factor(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<TwoFactorValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    check_session_password(c.ip(), &user, req.password).await?;
    if !user.can_use_two_factor(req.method) {
        let message = match req.method {
            TwoFactorMethod::Totp => "Set up your authenticator app before using it for two-factor authentication",
            _ => "Verify this email or phone number before using it for two-factor authentication",
        };
        return Err(ForgeError::unprocessable_entity().message(message));
    }

    if user.two_factor != Some(req.method) {
        let old = json!({ "two_factor": user.two_factor });
        let method = mongodb::bson::to_bson(&req.method).map_err(|e| {
            ForgeError::internal().caused_by(e).message("Invalid two-factor method")
        })?;
        user.update_fields(doc! { "two_factor": method }).await?;
        session()?.refresh_user(SessionUser::try_from(&user)?).await?;

        let description = match old["two_factor"].is_null() {
            true => "User enable two-factor",
            false => "User change two-factor method",
        };
        History::record(c, user.clone(), Some(old), Update, Some(description)).await;
    }

    c.response_ok(&SessionUser::try_from(&user)?)
}

/// `DELETE /api/users/two-factor` — body `{ "password" }`.
///
/// Exige sesión. Desactiva el segundo factor y borra la app de autenticación
/// (secreto incluido): para volver a usarla hay que configurarla de nuevo.
/// Responde el usuario de la sesión actualizado.
pub async fn disable_two_factor(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<PasswordValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    check_session_password(c.ip(), &user, req.password).await?;

    if user.two_factor.is_some() || user.totp_secret.is_some() {
        // El secreto no va al historial: solo si existía.
        let old = json!({
            "two_factor": user.two_factor,
            "totp_secret": user.totp_secret.is_some(),
            "totp_confirmed_at": user.totp_confirmed_at,
        });
        user.update_fields(doc! {
            "two_factor": null,
            "totp_secret": null,
            "totp_confirmed_at": null,
            "totp_last_step": null,
        })
        .await?;
        session()?.refresh_user(SessionUser::try_from(&user)?).await?;

        notify(&user, "user::disable_two_factor", |u| async move {
            mailer::account::send_two_factor_disabled(&u).await
        });
        History::record(c, user.clone(), Some(old), Update, Some("User disable two-factor")).await;
    }

    c.response_ok(&SessionUser::try_from(&user)?)
}

// ===============================================================================
// Cambio de email y teléfono
// ===============================================================================
// El dato nuevo queda en `pending_*` hasta confirmarlo, así el email y el teléfono
// de la cuenta siempre están verificados (y `two_factor` nunca apunta a un canal
// sin verificar). Al confirmar se avisa al dato anterior con un enlace para
// deshacer el cambio durante `REVERT_CHANGE_DAYS`.

/// `PUT /api/users/email` — body `{ "email", "password" }`.
///
/// Exige sesión. Guarda el email en `pending_email` y envía el enlace de
/// confirmación al email nuevo. Responde el usuario de la sesión actualizado.
pub async fn change_email(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<ChangeEmailValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    check_session_password(c.ip(), &user, req.password).await?;
    if req.email == user.email {
        return Err(ForgeError::unprocessable_entity().message("This is already your email address"));
    }
    if User::exists(doc! { "email": &req.email }).await? {
        return Err(ForgeError::conflict().message("Email already exists"));
    }

    user.update_fields(doc! { "pending_email": &req.email }).await?;
    session()?.refresh_user(SessionUser::try_from(&user)?).await?;
    mailer::account::send_change_email(&user).await?;

    c.response_ok(&SessionUser::try_from(&user)?)
}

/// `POST /api/users/email/confirm` — body `{ "token" }` (el del enlace al email nuevo).
///
/// No exige sesión: el enlace se puede abrir en otro navegador o dispositivo.
pub async fn confirm_email_change(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<LinkTokenValidator>().await?;

    let token = Token::consume_link(TokenType::ChangeEmail, &req.token).await?;
    let mut user = User::get_by_id(token.user_id).await?;

    // Si después pidió otro email (o deshizo el cambio), este enlace ya no sirve.
    let Some(new_email) = token.data_field("email").filter(|e| user.pending_email.as_deref() == Some(*e))
    else {
        return Err(ForgeError::gone().message("Email change cancelled, request a new confirmation link"));
    };
    let new_email = new_email.to_string();
    if User::exists(doc! { "email": &new_email }).await? {
        return Err(ForgeError::conflict().message("Email already exists"));
    }

    let old_email = user.email.clone();
    let old = json!({ "email": old_email, "email_verified_at": user.email_verified_at });
    let old_was_verified = user.email_verified_at.is_some();
    user.update_fields(doc! {
        "email": &new_email,
        "email_verified_at": DateTime::now(),
        "pending_email": null,
    })
    .await?;
    session()?.refresh_user(SessionUser::try_from(&user)?).await?;

    // Solo se avisa a un email que era del usuario (verificado).
    if old_was_verified {
        let notify_user = user.clone();
        tokio::spawn(async move {
            if let Err(e) = mailer::account::send_email_changed(&notify_user, &old_email).await {
                log::error(
                    "Failed to send email changed notice",
                    Some(json!({ "fn": "user::confirm_email_change", "user_id": notify_user.id, "error": e.to_string() })),
                );
            }
        });
    }

    History::record_with_user(token.user_id, user, Some(old), Update, Some("User change email")).await;

    c.response_no_content()
}

/// `POST /api/users/email/revert` — body `{ "token" }` (el del enlace al email anterior).
///
/// No exige sesión. Vuelve al email anterior y cierra todas las sesiones del
/// usuario: si el cambio no lo hizo él, quien lo hizo pierde el acceso.
pub async fn revert_email(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<LinkTokenValidator>().await?;

    let token = Token::consume_link(TokenType::RevertEmail, &req.token).await?;
    let mut user = User::get_by_id(token.user_id).await?;
    let old_email = token
        .data_field("email")
        .ok_or_else(|| ForgeError::internal().message("Revert token without email"))?
        .to_string();

    if User::exists(doc! { "email": &old_email, "_id": { "$ne": token.user_id } }).await? {
        return Err(ForgeError::conflict().message("This email address is now used by another account"));
    }

    let old = json!({ "email": user.email, "email_verified_at": user.email_verified_at, "pending_email": user.pending_email });
    user.update_fields(doc! {
        "email": &old_email,
        "email_verified_at": DateTime::now(),
        "pending_email": null,
    })
    .await?;
    session()?.invalidate_user(token.user_id).await?;

    History::record_with_user(token.user_id, user, Some(old), Update, Some("User revert email change")).await;

    c.response_no_content()
}

/// `PUT /api/users/phone` — body `{ "phone", "password" }` (con código de país).
///
/// Exige sesión. Guarda el teléfono en `pending_phone` y envía un código por
/// WhatsApp al teléfono nuevo. Responde el usuario de la sesión actualizado.
pub async fn change_phone(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<ChangePhoneValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    check_session_password(c.ip(), &user, req.password).await?;
    if req.phone == user.phone {
        return Err(ForgeError::unprocessable_entity().message("This is already your phone number"));
    }
    if User::exists(doc! { "phone": &req.phone }).await? {
        return Err(ForgeError::conflict().message("Phone already exists"));
    }

    user.update_fields(doc! { "pending_phone": &req.phone }).await?;
    session()?.refresh_user(SessionUser::try_from(&user)?).await?;
    whatsapp::account::send_change_phone(&user).await?;

    c.response_ok(&SessionUser::try_from(&user)?)
}

/// `POST /api/users/phone/confirm` — body `{ "code": "123456" }` (el que llegó al teléfono nuevo).
///
/// Exige sesión: el código son 6 dígitos y solo es válido junto al usuario.
/// Responde el usuario de la sesión actualizado.
pub async fn confirm_phone_change(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<CodeValidator>().await?;

    let token = Token::consume_code(auth.user_id, TokenType::ChangePhone, &req.code).await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    // Si después pidió otro teléfono (o deshizo el cambio), este código ya no sirve.
    let Some(new_phone) = token.data_field("phone").filter(|p| user.pending_phone.as_deref() == Some(*p))
    else {
        return Err(ForgeError::gone().message("Phone change cancelled, request a new verification code"));
    };
    let new_phone = new_phone.to_string();
    if User::exists(doc! { "phone": &new_phone }).await? {
        return Err(ForgeError::conflict().message("Phone already exists"));
    }

    let old_phone = user.phone.clone();
    let old = json!({ "phone": old_phone, "phone_verified_at": user.phone_verified_at });
    let old_was_verified = user.phone_verified_at.is_some();
    user.update_fields(doc! {
        "phone": &new_phone,
        "phone_verified_at": DateTime::now(),
        "pending_phone": null,
    })
    .await?;
    session()?.refresh_user(SessionUser::try_from(&user)?).await?;

    // Solo se avisa a un teléfono que era del usuario (verificado).
    if old_was_verified {
        let notify_user = user.clone();
        tokio::spawn(async move {
            if let Err(e) = whatsapp::account::send_phone_changed_notice(&notify_user, &old_phone).await {
                log::error(
                    "Failed to send phone changed notice",
                    Some(json!({ "fn": "user::confirm_phone_change", "user_id": notify_user.id, "error": e.to_string() })),
                );
            }
        });
    }

    History::record_with_user(auth.user_id, user.clone(), Some(old), Update, Some("User change phone")).await;

    c.response_ok(&SessionUser::try_from(&user)?)
}

/// `POST /api/users/phone/revert` — body `{ "token" }` (el del enlace al teléfono anterior).
///
/// No exige sesión. Vuelve al teléfono anterior y cierra todas las sesiones del
/// usuario: si el cambio no lo hizo él, quien lo hizo pierde el acceso.
pub async fn revert_phone(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<LinkTokenValidator>().await?;

    let token = Token::consume_link(TokenType::RevertPhone, &req.token).await?;
    let mut user = User::get_by_id(token.user_id).await?;
    let old_phone = token
        .data_field("phone")
        .ok_or_else(|| ForgeError::internal().message("Revert token without phone"))?
        .to_string();

    if User::exists(doc! { "phone": &old_phone, "_id": { "$ne": token.user_id } }).await? {
        return Err(ForgeError::conflict().message("This phone number is now used by another account"));
    }

    let old = json!({ "phone": user.phone, "phone_verified_at": user.phone_verified_at, "pending_phone": user.pending_phone });
    user.update_fields(doc! {
        "phone": &old_phone,
        "phone_verified_at": DateTime::now(),
        "pending_phone": null,
    })
    .await?;
    session()?.invalidate_user(token.user_id).await?;

    History::record_with_user(token.user_id, user, Some(old), Update, Some("User revert phone change")).await;

    c.response_no_content()
}

// ===============================================================================
// App de autenticación (TOTP)
// ===============================================================================

/// `POST /api/users/totp` — body `{ "password" }`.
///
/// Exige sesión. Genera un secreto nuevo y responde `{ "secret", "url", "qr" }`
/// para escanear el QR (o escribir el secreto) en la app de autenticación.
/// Queda sin confirmar hasta `POST /api/users/totp/confirm`.
pub async fn setup_totp(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<PasswordValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    check_session_password(c.ip(), &user, req.password).await?;
    // Un secreto nuevo invalida el de la app actual: si es el método del login,
    // el usuario quedaría sin poder usarlo hasta confirmar el nuevo.
    if user.two_factor == Some(TwoFactorMethod::Totp) {
        return Err(ForgeError::conflict().message(
            "Your authenticator app is your two-factor method, change it before setting up a new one",
        ));
    }

    totp::generate_secret(&mut user)?;
    user.update_fields(doc! {
        "totp_secret": &user.totp_secret,
        "totp_confirmed_at": null,
        "totp_last_step": null,
    })
    .await?;
    session()?.refresh_user(SessionUser::try_from(&user)?).await?;

    c.response_ok(&json!({
        "secret": totp::secret(&user)?,
        "url": totp::url(&user)?,
        "qr": totp::qr(&user)?,
    }))
}

/// `POST /api/users/totp/confirm` — body `{ "code": "123456" }` (el que muestra la app).
///
/// Exige sesión. Confirma que la app quedó bien configurada; desde ahí se puede
/// elegir `totp` en `PUT /api/users/two-factor`. Responde el usuario de la sesión actualizado.
pub async fn confirm_totp(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<CodeValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    if user.totp_confirmed_at.is_some() {
        return Err(ForgeError::conflict().message("Your authenticator app is already set up"));
    }
    totp::verify(&mut user, &req.code).await?;

    user.update_fields(doc! { "totp_confirmed_at": DateTime::now() }).await?;
    session()?.refresh_user(SessionUser::try_from(&user)?).await?;

    let old = json!({ "totp_confirmed_at": null });
    History::record(c, user.clone(), Some(old), Update, Some("User set up authenticator app")).await;

    c.response_ok(&SessionUser::try_from(&user)?)
}

// ===============================================================================
// Sesión
// ===============================================================================

/// `GET /api/users/me` — usuario de la sesión actual (o 401).
pub async fn me(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    c.response_ok(&*auth.user)
}

/// `POST /api/users/logout` — cierra la sesión actual. Sin sesión no es error.
pub async fn logout(c: &mut Context) -> Result<(), ForgeError> {
    c.logout().await?;
    c.response_no_content()
}

/// `POST /api/users/logout/all` — cierra todas las sesiones del usuario, incluida la actual.
pub async fn logout_all(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    session()?.invalidate_user(auth.user_id).await?;
    c.logout().await?;
    c.response_no_content()
}

/// `GET /api/users/sessions` — sesiones abiertas del usuario (dispositivos), la
/// más activa primero. `current` marca la de este request.
pub async fn sessions(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let list = session()?.list_user(auth.user_id, Some(&auth.session_id)).await?;
    c.response_ok(&list)
}

/// `DELETE /api/users/sessions/{id}` — cierra una sesión del usuario (el `id` de la lista).
pub async fn destroy_session(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let id = ObjectId::parse_str(c.require_param("id")?)
        .map_err(|_| ForgeError::bad_request().message("Invalid session id"))?;

    if !session()?.destroy_by_id(auth.user_id, id).await? {
        return Err(ForgeError::not_found().message("Session not found"));
    }
    c.response_no_content()
}

// ===============================================================================
// Contraseña
// ===============================================================================

/// Pedidos de recuperación por email/teléfono escrito y por IP en `FORGOT_WINDOW`:
/// cada pedido envía un email o WhatsApp.
const FORGOT_MAX_ACCOUNT: u32 = 3;
const FORGOT_MAX_IP: u32 = 10;
const FORGOT_WINDOW: Duration = Duration::from_secs(15 * 60);

/// `PUT /api/users/password` — body `{ "current_password", "password" }`.
///
/// Exige sesión. Cambia la contraseña, cierra las demás sesiones (la actual
/// sigue abierta) y avisa por email.
pub async fn change_password(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<ChangePasswordValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    check_session_password(c.ip(), &user, req.current_password.clone()).await?;
    if req.password == req.current_password {
        return Err(ForgeError::unprocessable_entity()
            .message("The new password must be different from the current one"));
    }

    user.password = req.password;
    user.hash_password().await?;
    let hash = user.password.clone();
    user.update_fields(doc! { "password": hash }).await?;
    session()?.invalidate_user_except(auth.user_id, &auth.session_id).await?;

    notify(&user, "user::change_password", |u| async move {
        mailer::account::send_password_changed(&u).await
    });
    History::record(c, user, None, Update, Some("User change password")).await;

    c.response_no_content()
}

/// `POST /api/users/password/forgot` — body `{ "user" }` (email o teléfono con código de país).
///
/// Con email envía un enlace; con teléfono, un código por WhatsApp. Responde
/// `202` con `{ "method" }` exista o no la cuenta, para no revelarlo.
pub async fn forgot_password(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<ForgotPasswordValidator>().await?;

    let mut limits = vec![Limit::new(format!("forgot:account:{}", req.user), FORGOT_MAX_ACCOUNT, FORGOT_WINDOW)];
    if let Some(ip) = c.ip() {
        limits.push(Limit::new(format!("forgot:ip:{ip}"), FORGOT_MAX_IP, FORGOT_WINDOW));
    }
    Throttle::check(&limits).await?;
    Throttle::hit(&limits).await?;

    let (filter, method) = if req.is_email() {
        (doc! { "email": &req.user }, TwoFactorMethod::Email)
    } else {
        (doc! { "phone": &req.user }, TwoFactorMethod::Whatsapp)
    };
    // Se envía en segundo plano: la respuesta tarda lo mismo exista o no la cuenta.
    if let Some(user) = User::find::<User>(filter)?.limit(1).get().await?.pop()
        && user.deleted_at.is_none()
    {
        notify(&user, "user::forgot_password", move |u| async move {
            match method {
                TwoFactorMethod::Email => mailer::account::send_reset_password(&u).await,
                _ => whatsapp::account::send_reset_password(&u).await,
            }
        });
    }

    c.response_accepted(&json!({ "method": method }))
}

/// `POST /api/users/password/reset` — body `{ "token", "password" }` (el del enlace del email).
///
/// No exige sesión. Cambia la contraseña, marca el email como verificado (el
/// enlace lo prueba) y cierra todas las sesiones.
pub async fn reset_password(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<ResetPasswordValidator>().await?;

    let token = Token::consume_link(TokenType::ResetPassword, &req.token).await?;
    let mut user = User::get_by_id(token.user_id).await?;
    if user.deleted_at.is_some() {
        return Err(ForgeError::gone().message("This account no longer exists"));
    }
    if token.data_field("email") != Some(user.email.as_str()) {
        return Err(ForgeError::gone().message("Email changed, request a new recovery link"));
    }

    set_new_password(&mut user, req.password, "email_verified_at").await?;
    History::record_with_user(token.user_id, user, None, Update, Some("User reset password by email")).await;

    c.response_no_content()
}

/// `POST /api/users/password/reset/code` — body `{ "phone", "code", "password" }`
/// (el código que llegó por WhatsApp).
///
/// No exige sesión. Cambia la contraseña, marca el teléfono como verificado (el
/// código lo prueba) y cierra todas las sesiones.
pub async fn reset_password_code(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<ResetPasswordCodeValidator>().await?;
    let invalid = || ForgeError::not_found().message("Invalid or expired code");

    let Some(mut user) = User::find::<User>(doc! { "phone": &req.phone })?.limit(1).get().await?.pop() else {
        return Err(invalid());
    };
    if user.deleted_at.is_some() {
        return Err(invalid());
    }
    let user_id = id_of(&user)?;

    let token = Token::consume_code(user_id, TokenType::ResetPasswordCode, &req.code).await?;
    if token.data_field("phone") != Some(user.phone.as_str()) {
        return Err(ForgeError::gone().message("Phone changed, request a new recovery code"));
    }

    set_new_password(&mut user, req.password, "phone_verified_at").await?;
    History::record_with_user(user_id, user, None, Update, Some("User reset password by WhatsApp")).await;

    c.response_no_content()
}

/// Guarda la contraseña nueva de una recuperación: marca como verificado el canal
/// que la probó (`verified_field`), cierra todas las sesiones, reinicia el límite
/// de intentos de la cuenta y avisa por email.
async fn set_new_password(user: &mut User, password: String, verified_field: &str) -> Result<(), ForgeError> {
    let user_id = id_of(user)?;
    user.password = password;
    user.hash_password().await?;

    let mut fields = doc! { "password": user.password.clone() };
    let verified = match verified_field {
        "email_verified_at" => user.email_verified_at.is_some(),
        _ => user.phone_verified_at.is_some(),
    };
    if !verified {
        fields.insert(verified_field, DateTime::now());
    }
    user.update_fields(fields).await?;
    session()?.invalidate_user(user_id).await?;
    Throttle::clear(&password_account_key(&user_id.to_hex())).await;

    notify(user, "user::set_new_password", |u| async move {
        mailer::account::send_password_changed(&u).await
    });
    Ok(())
}

// ===============================================================================
// Reenviar verificación
// ===============================================================================

/// Reenvíos por usuario en `RESEND_WINDOW`: cada uno envía un email o WhatsApp.
const RESEND_MAX: u32 = 3;
const RESEND_WINDOW: Duration = Duration::from_secs(15 * 60);

/// `POST /api/users/verify/email/resend` — exige sesión. Envía un enlace nuevo
/// (el anterior deja de servir).
pub async fn resend_verify_email(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let user = User::get_by_id(auth.user_id).await?;
    if user.email_verified_at.is_some() {
        return Err(ForgeError::conflict().message("Your email address is already verified"));
    }

    let limits = [Limit::new(format!("resend:verify-email:{}", auth.user_id), RESEND_MAX, RESEND_WINDOW)];
    Throttle::check(&limits).await?;
    Throttle::hit(&limits).await?;
    mailer::account::send_verify_email(&user).await?;

    c.response_no_content()
}

/// `POST /api/users/verify/phone/resend` — exige sesión. Envía un código nuevo
/// por WhatsApp (el anterior deja de servir).
pub async fn resend_verify_phone(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let user = User::get_by_id(auth.user_id).await?;
    if user.phone_verified_at.is_some() {
        return Err(ForgeError::conflict().message("Your phone number is already verified"));
    }

    let limits = [Limit::new(format!("resend:verify-phone:{}", auth.user_id), RESEND_MAX, RESEND_WINDOW)];
    Throttle::check(&limits).await?;
    Throttle::hit(&limits).await?;
    whatsapp::account::send_verify_phone(&user).await?;

    c.response_no_content()
}

// ===============================================================================
// Cancelar cambio pendiente
// ===============================================================================

/// `DELETE /api/users/email/pending` — exige sesión. Descarta el email nuevo sin
/// confirmar (su enlace deja de servir). Responde el usuario de la sesión actualizado.
pub async fn cancel_email_change(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    if user.pending_email.is_some() {
        user.update_fields(doc! { "pending_email": null }).await?;
        session()?.refresh_user(SessionUser::try_from(&user)?).await?;
    }
    c.response_ok(&SessionUser::try_from(&user)?)
}

/// `DELETE /api/users/phone/pending` — exige sesión. Descarta el teléfono nuevo
/// sin confirmar (su código deja de servir). Responde el usuario de la sesión actualizado.
pub async fn cancel_phone_change(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    if user.pending_phone.is_some() {
        user.update_fields(doc! { "pending_phone": null }).await?;
        session()?.refresh_user(SessionUser::try_from(&user)?).await?;
    }
    c.response_ok(&SessionUser::try_from(&user)?)
}

// ===============================================================================
// Eliminar cuenta
// ===============================================================================

/// `DELETE /api/users/me` — body `{ "password" }`.
///
/// Exige sesión. Borrado lógico (`deleted_at`): la cuenta ya no puede iniciar
/// sesión, se borran el segundo factor y los cambios pendientes, y se cierran
/// todas las sesiones.
pub async fn delete_account(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<PasswordValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    check_session_password(c.ip(), &user, req.password).await?;

    user.update_fields(doc! {
        "deleted_at": DateTime::now(),
        "two_factor": null,
        "totp_secret": null,
        "totp_confirmed_at": null,
        "totp_last_step": null,
        "pending_email": null,
        "pending_phone": null,
        "remember_token": null,
    })
    .await?;
    session()?.invalidate_user(auth.user_id).await?;
    c.logout().await?;

    // Ya sin sesión: el historial se registra con el id.
    History::record_with_user(auth.user_id, user, None, Delete, Some("User delete account")).await;

    c.response_no_content()
}

// ===============================================================================
// Utilidades
// ===============================================================================

/// Contraseñas incorrectas permitidas en `PASSWORD_WINDOW`, por cuenta y por IP.
/// Aplica al login y a toda acción con sesión que pida la contraseña.
const PASSWORD_MAX_ACCOUNT: u32 = 5;
/// Más alto que por cuenta: varios usuarios pueden compartir IP (ej. el wifi del spa).
const PASSWORD_MAX_IP: u32 = 30;
const PASSWORD_WINDOW: Duration = Duration::from_secs(15 * 60);

fn password_account_key(account: &str) -> String {
    format!("password:account:{account}")
}

/// Límites de contraseña para una cuenta (id en hex, o lo escrito en el login si
/// no existe). El primero siempre es el de la cuenta.
fn password_limits(ip: Option<IpAddr>, account: &str) -> Vec<Limit> {
    let mut limits = vec![Limit::new(password_account_key(account), PASSWORD_MAX_ACCOUNT, PASSWORD_WINDOW)];
    if let Some(ip) = ip {
        limits.push(Limit::new(format!("password:ip:{ip}"), PASSWORD_MAX_IP, PASSWORD_WINDOW));
    }
    limits
}

/// Contraseña de un usuario con sesión (acciones sensibles), con el mismo límite
/// de intentos que el login.
/// Recibe la IP y no el `Context`: este no es `Sync` y no puede cruzar un `.await`.
async fn check_session_password(ip: Option<IpAddr>, user: &User, password: String) -> Result<(), ForgeError> {
    let limits = password_limits(ip, &id_of(user)?.to_hex());
    Throttle::check(&limits).await?;
    if !user.check_password(password).await? {
        Throttle::hit(&limits).await?;
        return Err(ForgeError::forbidden().message("The password is incorrect"));
    }
    Throttle::clear(&limits[0].key).await;
    Ok(())
}

fn id_of(user: &User) -> Result<ObjectId, ForgeError> {
    user.id
        .ok_or_else(|| ForgeError::internal().message("User without id"))
}

/// Envía un aviso en segundo plano: no demora la respuesta y si falla solo se
/// registra en el log.
fn notify<F, Fut>(user: &User, origin: &'static str, send: F)
where
    F: FnOnce(User) -> Fut + Send + 'static,
    Fut: std::future::Future<Output = Result<(), ForgeError>> + Send,
{
    let user = user.clone();
    tokio::spawn(async move {
        let user_id = user.id;
        if let Err(e) = send(user).await {
            log::error(
                "Failed to send notification",
                Some(json!({ "fn": origin, "user_id": user_id, "error": e.to_string() })),
            );
        }
    });
}

