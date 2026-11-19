//! Páginas HTML de la web (Askama). Las plantillas están en esta carpeta
//! (`askama.toml` → `dirs = ["src/app/ui"]`), con la misma estructura que la app
//! mobile: `shell/`, `components/` y `pages/<módulo>/`.
//!
//! El HTML sale completo del servidor; el JS (Dart compilado, `web/`) solo
//! envía los formularios a la API y muestra los errores.

use askama::Template;
use chrono::{DateTime as ChronoDateTime, FixedOffset, Utc};
use hyper::header;
use ironforge::{Context, ForgeError};
use mongodb::bson::DateTime;

use crate::app::shared::models::user::{DocumentType, Theme, TwoFactorMethod};
use crate::app::shared::resources::session_user::SessionUser;

/// Nombre del local, igual que `APP_NAME` de la app mobile.
pub const APP_NAME: &str = "MR Nails";

/// Las fechas con hora se muestran en hora de Colombia (UTC−5, sin horario de verano).
const LOCAL_OFFSET_SECONDS: i32 = -5 * 3600;

// === Render =====================================================

/// Responde la plantilla como `text/html`.
pub fn render(c: &mut Context, page: &impl Template) -> Result<(), ForgeError> {
    let html = page
        .render()
        .map_err(|e| ForgeError::internal().message("Failed to render page").caused_by(e))?;
    c.set_header(header::CONTENT_TYPE, "text/html; charset=utf-8")?;
    // El HTML lleva datos del usuario y el token CSRF: que no lo guarde ningún caché.
    c.set_header(header::CACHE_CONTROL, "no-store")?;
    c.set_header(header::X_CONTENT_TYPE_OPTIONS, "nosniff")?;
    c.set_header(header::X_FRAME_OPTIONS, "DENY")?;
    c.set_header(header::REFERRER_POLICY, "same-origin")?;
    c.response_into(200, html.into())
}

/// `303 See Other` hacia `to` (una ruta propia, ej. `/login`).
pub fn redirect(c: &mut Context, to: &str) -> Result<(), ForgeError> {
    c.set_header(header::LOCATION, to)?;
    c.set_header(header::CACHE_CONTROL, "no-store")?;
    c.response_into(303, Default::default())
}

// === Shell ======================================================

/// Secciones del menú lateral (`AppSection` en mobile).
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Section {
    Home,
    Profile,
    /// Login y registro: sin menú.
    None,
}

/// Lo que necesita toda página: título, sesión, token CSRF y tema.
pub struct Shell {
    pub title: &'static str,
    pub section: Section,
    pub user: Option<UserView>,
    pub csrf: String,
}

impl Shell {
    pub fn new(c: &Context, title: &'static str, section: Section, user: Option<&SessionUser>) -> Result<Self, ForgeError> {
        Ok(Self {
            title,
            section,
            user: user.map(UserView::from),
            csrf: ironforge::csrf(c)?,
        })
    }

    pub fn app_name(&self) -> &'static str {
        APP_NAME
    }

    /// Monograma de la marca: "MR Nails" → "MR".
    pub fn brand_initials(&self) -> String {
        brand_initials(APP_NAME)
    }

    /// `data-theme` del `<html>`; sin preferencia sigue al sistema.
    pub fn theme(&self) -> &'static str {
        match self.user.as_ref().and_then(|u| u.theme) {
            Some(Theme::Light) => "light",
            Some(Theme::Dark) => "dark",
            None => "",
        }
    }

    pub fn is(&self, section: Section) -> bool {
        self.section == section
    }
}

// === Usuario ====================================================

/// Datos del usuario ya preparados para mostrar.
pub struct UserView {
    pub name: String,
    pub first_name: String,
    pub initials: String,
    pub nickname: String,
    pub email: String,
    pub phone: String,
    pub pending_email: Option<String>,
    pub pending_phone: Option<String>,
    pub email_verified: bool,
    pub phone_verified: bool,
    pub two_factor: Option<TwoFactorMethod>,
    pub totp_confirmed: bool,
    pub google_linked: bool,
    pub roles: String,
    pub created_at: String,
    /// `aaaa-mm-dd` para el `<input type="date">`; vacío si no tiene.
    pub birthdate_iso: String,
    /// `dd/mm/aaaa`, o "—".
    pub birthdate: String,
    /// Código (`"CC"`) para el `<select>`; vacío si no tiene.
    pub document_type: String,
    pub document_number: String,
    /// "CC 1234", o "—".
    pub document: String,
    pub address: String,
    pub city: String,
    pub theme: Option<Theme>,
}

impl From<&SessionUser> for UserView {
    fn from(u: &SessionUser) -> Self {
        let birthdate = u.birthdate.map(utc_date);
        let theme = u
            .preferences
            .get("theme")
            .and_then(|t| serde_json::from_value::<Theme>(t.clone()).ok());
        Self {
            name: u.name.clone(),
            first_name: u.name.split_whitespace().next().unwrap_or_default().to_string(),
            initials: initials(&u.name),
            nickname: u.nickname.clone(),
            email: u.email.clone(),
            phone: u.phone.clone(),
            pending_email: u.pending_email.clone(),
            pending_phone: u.pending_phone.clone(),
            email_verified: u.email_verified_at.is_some(),
            phone_verified: u.phone_verified_at.is_some(),
            two_factor: u.two_factor,
            totp_confirmed: u.totp_confirmed_at.is_some(),
            google_linked: u.google_linked,
            roles: if u.roles.is_empty() { "Sin roles".into() } else { u.roles.join(", ") },
            created_at: local_date(u.created_at).format("%d/%m/%Y").to_string(),
            birthdate_iso: birthdate.map(|d| d.format("%Y-%m-%d").to_string()).unwrap_or_default(),
            birthdate: birthdate.map_or_else(|| EMPTY.into(), |d| d.format("%d/%m/%Y").to_string()),
            document_type: u.document_type.map(|t| t.code().to_string()).unwrap_or_default(),
            document_number: u.document.clone().unwrap_or_default(),
            document: match (u.document_type, &u.document) {
                (Some(t), Some(n)) => format!("{} {n}", t.code()),
                _ => EMPTY.into(),
            },
            address: u.address.clone().unwrap_or_default(),
            city: u.city.clone().unwrap_or_default(),
            theme,
        }
    }
}

impl UserView {
    /// Etiqueta del segundo factor ("Por correo"...) o `None` si está desactivado.
    pub fn two_factor_label(&self) -> Option<&'static str> {
        self.two_factor.map(two_factor_label)
    }

    pub fn theme_label(&self) -> &'static str {
        match self.theme {
            Some(Theme::Light) => "Claro",
            Some(Theme::Dark) => "Oscuro",
            None => "Según el dispositivo",
        }
    }

    /// `true` si el tema elegido es `name` ("light" / "dark").
    pub fn theme_is(&self, name: &str) -> bool {
        matches!((self.theme, name), (Some(Theme::Light), "light") | (Some(Theme::Dark), "dark"))
    }

    pub fn or_empty<'a>(&self, value: &'a str) -> &'a str {
        if value.is_empty() { EMPTY } else { value }
    }
}

/// Valor vacío en las filas de datos.
pub const EMPTY: &str = "—";

/// Tipos de documento para el `<select>`: código y nombre.
pub const DOCUMENT_TYPES: [(&str, &str); 6] = [
    (DocumentType::Cc.code(), "Cédula de ciudadanía"),
    (DocumentType::Ce.code(), "Cédula de extranjería"),
    (DocumentType::Ti.code(), "Tarjeta de identidad"),
    (DocumentType::Pp.code(), "Pasaporte"),
    (DocumentType::Ppt.code(), "Permiso por protección temporal"),
    (DocumentType::Nit.code(), "NIT"),
];

pub fn two_factor_label(method: TwoFactorMethod) -> &'static str {
    match method {
        TwoFactorMethod::Email => "Por correo",
        TwoFactorMethod::Whatsapp => "Por WhatsApp",
        TwoFactorMethod::Totp => "App de autenticación",
    }
}

// === Helpers ====================================================

/// Iniciales de las dos primeras palabras: "Ana María Pérez" → "AM".
pub fn initials(name: &str) -> String {
    name.split_whitespace()
        .take(2)
        .filter_map(|w| w.chars().next())
        .flat_map(char::to_uppercase)
        .collect()
}

/// La primera palabra si es una sigla ("MR Nails" → "MR"); si no, las iniciales.
fn brand_initials(name: &str) -> String {
    match name.split_whitespace().next() {
        Some(first) if first.chars().count() <= 3 && first == first.to_uppercase() => first.to_string(),
        _ => initials(name),
    }
}

/// Fechas sin hora (nacimiento): el backend las guarda a medianoche UTC.
fn utc_date(date: DateTime) -> ChronoDateTime<Utc> {
    ChronoDateTime::from_timestamp_millis(date.timestamp_millis()).unwrap_or_default()
}

fn local_date(date: DateTime) -> ChronoDateTime<FixedOffset> {
    let offset = FixedOffset::east_opt(LOCAL_OFFSET_SECONDS).expect("offset válido");
    utc_date(date).with_timezone(&offset)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn iniciales() {
        assert_eq!(initials("Ana María Pérez"), "AM");
        assert_eq!(initials("  ñoño  "), "Ñ");
        assert_eq!(initials(""), "");
        assert_eq!(brand_initials("MR Nails"), "MR");
        assert_eq!(brand_initials("Spa Nails"), "SN");
    }

    #[test]
    fn fechas() {
        // 2026-11-18 03:00 UTC es todavía el 17 en Colombia.
        let d = DateTime::from_millis(1_794_970_800_000);
        assert_eq!(utc_date(d).format("%d/%m/%Y").to_string(), "18/11/2026");
        assert_eq!(local_date(d).format("%d/%m/%Y").to_string(), "17/11/2026");
    }
}
