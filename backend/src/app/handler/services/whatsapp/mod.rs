//! Envío de mensajes por la WhatsApp Cloud API de Meta con la config de
//! `env.json` → `extensions.whatsapp`.
//!
//! Solo se envían plantillas de autenticación (código de un solo uso con botón
//! "copiar código"): es lo único que Meta permite mandar a un usuario que no
//! ha escrito antes al número del negocio.

pub mod account;

use std::{sync::OnceLock, time::Duration};

use ironforge::{ForgeError, env, log};
use serde::Deserialize;
use serde_json::{Value, json};

// ===============================================================================
// Configuración: env.json → extensions.whatsapp
// ===============================================================================

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct WhatsappEnv {
    /// Base de la Graph API (sin versión).
    pub api_url: String,
    /// Versión de la Graph API, ej. `v23.0`.
    pub api_version: String,
    /// ID del número de teléfono del negocio (WhatsApp Manager → API Setup).
    pub phone_number_id: String,
    /// Token permanente de un usuario del sistema con el permiso `whatsapp_business_messaging`.
    pub access_token: String,
    /// Nombre de la plantilla de autenticación aprobada (categoría AUTHENTICATION,
    /// con botón "copiar código").
    pub otp_template: String,
    /// Idioma con el que se aprobó la plantilla, ej. `es_MX`.
    pub template_language: String,
    pub timeout_seconds: u64,
}

impl Default for WhatsappEnv {
    fn default() -> Self {
        Self {
            api_url: "https://graph.facebook.com".into(),
            api_version: "v23.0".into(),
            phone_number_id: String::new(),
            access_token: String::new(),
            otp_template: String::new(),
            template_language: "es_MX".into(),
            timeout_seconds: 10,
        }
    }
}

struct Whatsapp {
    http: reqwest::Client,
    /// `{api_url}/{api_version}/{phone_number_id}/messages`
    messages_url: String,
    access_token: String,
    otp_template: String,
    template_language: String,
}

/// Se arma una vez con `extensions.whatsapp` y se reutiliza (reqwest mantiene un pool de conexiones).
fn whatsapp() -> Result<&'static Whatsapp, ForgeError> {
    static WHATSAPP: OnceLock<Result<Whatsapp, String>> = OnceLock::new();
    WHATSAPP
        .get_or_init(build_whatsapp)
        .as_ref()
        .map_err(|e| ForgeError::internal().message(format!("WhatsApp is not configured: {e}")))
}

fn build_whatsapp() -> Result<Whatsapp, String> {
    let cfg: WhatsappEnv = match env().extensions.get("whatsapp") {
        Some(v) => serde_json::from_value(v.clone()).map_err(|e| format!("extensions.whatsapp: {e}"))?,
        None => WhatsappEnv::default(),
    };

    for (key, value) in [
        ("phone_number_id", &cfg.phone_number_id),
        ("access_token", &cfg.access_token),
        ("otp_template", &cfg.otp_template),
    ] {
        if value.is_empty() {
            return Err(format!("extensions.whatsapp.{key} is empty"));
        }
    }

    // El servidor ya instala aws-lc-rs al arrancar; esto cubre el caso de usar
    // el cliente antes (ej. un comando de consola). Si ya hay uno, no hace nada.
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();

    let http = reqwest::Client::builder()
        .timeout(Duration::from_secs(cfg.timeout_seconds))
        .build()
        .map_err(|e| format!("http client: {e}"))?;

    Ok(Whatsapp {
        http,
        messages_url: format!(
            "{}/{}/{}/messages",
            cfg.api_url.trim_end_matches('/'),
            cfg.api_version,
            cfg.phone_number_id
        ),
        access_token: cfg.access_token,
        otp_template: cfg.otp_template,
        template_language: cfg.template_language,
    })
}

// ===============================================================================
// Envío
// ===============================================================================

/// Envía un código de un solo uso con la plantilla de autenticación.
/// `phone_code` con `+` (ej. `+52`) y `phone` solo dígitos, como se guardan en `User`.
pub async fn send_otp(phone_code: &str, phone: &str, code: &str) -> Result<(), ForgeError> {
    let wa = whatsapp()?;

    // Las plantillas de autenticación llevan el código dos veces: en el cuerpo
    // y en el botón "copiar código".
    let body = json!({
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": to_number(phone_code, phone),
        "type": "template",
        "template": {
            "name": wa.otp_template,
            "language": { "code": wa.template_language },
            "components": [
                { "type": "body", "parameters": [{ "type": "text", "text": code }] },
                {
                    "type": "button",
                    "sub_type": "url",
                    "index": "0",
                    "parameters": [{ "type": "text", "text": code }]
                }
            ]
        }
    });

    let res = wa
        .http
        .post(&wa.messages_url)
        .bearer_auth(&wa.access_token)
        .json(&body)
        .send()
        .await
        .map_err(|e| {
            log::error(
                "Failed to send WhatsApp message",
                Some(json!({ "fn": "whatsapp::send_otp", "error": e.to_string() })),
            );
            ForgeError::internal().caused_by(e).message("Failed to send WhatsApp message")
        })?;

    if !res.status().is_success() {
        let status = res.status().as_u16();
        // Meta responde `{ "error": { "message", "code", "error_data": { "details" } } }`.
        let error: Value = res.json().await.unwrap_or(Value::Null);
        log::error(
            "WhatsApp API rejected the message",
            Some(json!({ "fn": "whatsapp::send_otp", "status": status, "error": error["error"] })),
        );
        return Err(ForgeError::internal().message("Failed to send WhatsApp message"));
    }

    Ok(())
}

/// Número en formato internacional sin `+` ni separadores, ej. `+52` + `5512345678` → `525512345678`.
fn to_number(phone_code: &str, phone: &str) -> String {
    phone_code
        .chars()
        .chain(phone.chars())
        .filter(char::is_ascii_digit)
        .collect()
}
