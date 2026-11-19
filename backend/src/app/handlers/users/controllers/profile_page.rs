//! Páginas del perfil: resumen, autenticación, datos personales y preferencias.
//! Sin sesión llevan al login.

use askama::Template;
use ironforge::{Context, ForgeError};

use crate::app::shared::resources::session_user::SessionUser;
use crate::app::ui::{DOCUMENT_TYPES, Section, Shell, redirect, render};

/// Pantallas del perfil (`ProfileTab` en mobile).
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ProfileTab {
    Overview,
    Account,
    Personal,
    Preferences,
}

const TABS: &[ProfileTab] = &[ProfileTab::Overview, ProfileTab::Account, ProfileTab::Personal, ProfileTab::Preferences];

impl ProfileTab {
    pub fn title(&self) -> &'static str {
        match self {
            Self::Overview => "Mi perfil",
            Self::Account => "Autenticación",
            Self::Personal => "Datos personales",
            Self::Preferences => "Preferencias",
        }
    }

    /// Para la barra de abajo, donde no cabe el título completo.
    pub fn short_label(&self) -> &'static str {
        match self {
            Self::Overview => "Perfil",
            Self::Account => "Acceso",
            Self::Personal => "Datos",
            Self::Preferences => "Preferencias",
        }
    }

    pub fn icon(&self) -> &'static str {
        match self {
            Self::Overview => "person",
            Self::Account => "lock",
            Self::Personal => "badge",
            Self::Preferences => "tune",
        }
    }

    pub fn href(&self) -> &'static str {
        match self {
            Self::Overview => "/profile",
            Self::Account => "/profile/account",
            Self::Personal => "/profile/personal",
            Self::Preferences => "/profile/preferences",
        }
    }
}

#[derive(Template)]
#[template(path = "pages/profile/profile_overview.html")]
struct OverviewPage {
    shell: Shell,
    tab: ProfileTab,
    tabs: &'static [ProfileTab],
}

#[derive(Template)]
#[template(path = "pages/profile/account_page.html")]
struct AccountPage {
    shell: Shell,
    tab: ProfileTab,
    tabs: &'static [ProfileTab],
}

#[derive(Template)]
#[template(path = "pages/profile/personal_page.html")]
struct PersonalPage {
    shell: Shell,
    tab: ProfileTab,
    tabs: &'static [ProfileTab],
    document_types: &'static [(&'static str, &'static str)],
}

#[derive(Template)]
#[template(path = "pages/profile/preferences_page.html")]
struct PreferencesPage {
    shell: Shell,
    tab: ProfileTab,
    tabs: &'static [ProfileTab],
}

/// El shell de la pestaña, o `None` si no hay sesión (ya respondió el redirect).
async fn shell(c: &mut Context, tab: ProfileTab) -> Result<Option<Shell>, ForgeError> {
    let Some(auth) = c.try_auth::<SessionUser>().await? else {
        redirect(c, "/login")?;
        return Ok(None);
    };
    Shell::new(c, tab.title(), Section::Profile, Some(&auth.user)).map(Some)
}

/// `GET /profile`
pub async fn overview(c: &mut Context) -> Result<(), ForgeError> {
    let tab = ProfileTab::Overview;
    let Some(shell) = shell(c, tab).await? else { return Ok(()) };
    render(c, &OverviewPage { shell, tab, tabs: TABS })
}

/// `GET /profile/account`
pub async fn account(c: &mut Context) -> Result<(), ForgeError> {
    let tab = ProfileTab::Account;
    let Some(shell) = shell(c, tab).await? else { return Ok(()) };
    render(c, &AccountPage { shell, tab, tabs: TABS })
}

/// `GET /profile/personal`
pub async fn personal(c: &mut Context) -> Result<(), ForgeError> {
    let tab = ProfileTab::Personal;
    let Some(shell) = shell(c, tab).await? else { return Ok(()) };
    render(c, &PersonalPage { shell, tab, tabs: TABS, document_types: &DOCUMENT_TYPES })
}

/// `GET /profile/preferences`
pub async fn preferences(c: &mut Context) -> Result<(), ForgeError> {
    let tab = ProfileTab::Preferences;
    let Some(shell) = shell(c, tab).await? else { return Ok(()) };
    render(c, &PreferencesPage { shell, tab, tabs: TABS })
}
