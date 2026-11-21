//! Páginas de login y registro. Los formularios los envía el JS (`web/`) a
//! `/api/users/auth/...`; aquí solo se arma el HTML.

use askama::Template;
use ironforge::{Context, ForgeError};

use crate::app::shared::resources::session_user::SessionUser;
use crate::app::ui::{Shell, Section, redirect, render};

#[derive(Template)]
#[template(path = "pages/auth/login_page.html")]
struct LoginPage {
    shell: Shell,
}

#[derive(Template)]
#[template(path = "pages/auth/register_page.html")]
struct RegisterPage {
    shell: Shell,
}

#[derive(Template)]
#[template(path = "pages/auth/verify_email_page.html")]
struct VerifyEmailPage {
    shell: Shell,
}

#[derive(Template)]
#[template(path = "pages/auth/forgot_password_page.html")]
struct ForgotPasswordPage {
    shell: Shell,
}

#[derive(Template)]
#[template(path = "pages/auth/reset_password_page.html")]
struct ResetPasswordPage {
    shell: Shell,
}

/// `GET /forgot-password` — pide el enlace (email) o el código (WhatsApp). No
/// exige ni rechaza la sesión: también se llega desde el perfil.
pub async fn forgot_password_page(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.try_auth::<SessionUser>().await?;
    let shell = Shell::new(c, "Recuperar contraseña", Section::None, auth.as_ref().map(|a| &*a.user))?;
    render(c, &ForgotPasswordPage { shell })
}

/// `GET /reset-password?token=...` — el enlace del email de recuperación; el JS
/// envía el token y la contraseña nueva a `POST /api/users/auth/password/reset`.
pub async fn reset_password_page(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.try_auth::<SessionUser>().await?;
    let shell = Shell::new(c, "Nueva contraseña", Section::None, auth.as_ref().map(|a| &*a.user))?;
    render(c, &ResetPasswordPage { shell })
}

/// `GET /verify-email?token=...` — el enlace del email de verificación. No
/// exige sesión (se puede abrir en otro dispositivo); el JS lee el token de la
/// URL y lo envía a `POST /api/users/auth/verify/email`.
pub async fn verify_email_page(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.try_auth::<SessionUser>().await?;
    let shell = Shell::new(c, "Verificar correo", Section::None, auth.as_ref().map(|a| &*a.user))?;
    render(c, &VerifyEmailPage { shell })
}

/// `GET /login` — con sesión vuelve al inicio.
pub async fn login_page(c: &mut Context) -> Result<(), ForgeError> {
    if c.try_auth::<SessionUser>().await?.is_some() {
        return redirect(c, "/");
    }
    let shell = Shell::new(c, "Iniciar sesión", Section::None, None)?;
    render(c, &LoginPage { shell })
}

/// `GET /register` — con sesión vuelve al inicio.
pub async fn register_page(c: &mut Context) -> Result<(), ForgeError> {
    if c.try_auth::<SessionUser>().await?.is_some() {
        return redirect(c, "/");
    }
    let shell = Shell::new(c, "Crear cuenta", Section::None, None)?;
    render(c, &RegisterPage { shell })
}
