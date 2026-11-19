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
