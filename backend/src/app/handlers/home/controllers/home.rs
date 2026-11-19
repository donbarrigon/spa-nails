use askama::Template;
use ironforge::{Context, ForgeError};

use crate::app::shared::resources::session_user::SessionUser;
use crate::app::ui::{Section, Shell, render};

#[derive(Template)]
#[template(path = "pages/home/home_page.html")]
struct HomePage {
    shell: Shell,
}

/// `GET /` — inicio, con o sin sesión.
pub async fn home(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.try_auth::<SessionUser>().await?;
    let shell = Shell::new(c, "Inicio", Section::Home, auth.as_ref().map(|a| &*a.user))?;
    render(c, &HomePage { shell })
}
