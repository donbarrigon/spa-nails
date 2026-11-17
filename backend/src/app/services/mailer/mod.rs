//! Envío de emails por SMTP (lettre) con la config de `env.json` → `extensions.mail`.

pub mod account;
mod templates;

use std::{sync::OnceLock, time::Duration};

use ironforge::{ForgeError, env, log};
use lettre::{
    AsyncSmtpTransport, AsyncTransport, Message, Tokio1Executor,
    message::{Mailbox, MultiPart},
    transport::smtp::authentication::Credentials,
};
use serde::Deserialize;
use serde_json::json;

// ===============================================================================
// Configuración: env.json → extensions.mail
// ===============================================================================

#[derive(Debug, Clone, Copy, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Encryption {
    /// TLS desde la conexión (normalmente puerto 465).
    Tls,
    /// Conexión en claro que pasa a TLS con STARTTLS (normalmente puerto 587).
    Starttls,
    /// Sin cifrado. Solo para un SMTP local de desarrollo (ej. Mailpit en el 1025).
    None,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct MailEnv {
    pub host: String,
    pub port: u16,
    pub encryption: Encryption,
    pub username: String,
    pub password: String,
    pub from_address: String,
    pub from_name: String,
    pub timeout_seconds: u64,
}

impl Default for MailEnv {
    fn default() -> Self {
        Self {
            host: "localhost".into(),
            port: 1025,
            encryption: Encryption::None,
            username: String::new(),
            password: String::new(),
            from_address: "no-reply@localhost".into(),
            from_name: "MR nails".into(),
            timeout_seconds: 10,
        }
    }
}

struct Mailer {
    transport: AsyncSmtpTransport<Tokio1Executor>,
    from: Mailbox,
}

/// Se arma una vez con `extensions.mail` y se reutiliza (lettre mantiene un pool de conexiones).
fn mailer() -> Result<&'static Mailer, ForgeError> {
    static MAILER: OnceLock<Result<Mailer, String>> = OnceLock::new();
    MAILER
        .get_or_init(build_mailer)
        .as_ref()
        .map_err(|e| ForgeError::internal().message(format!("Mail is not configured: {e}")))
}

fn build_mailer() -> Result<Mailer, String> {
    let cfg: MailEnv = match env().extensions.get("mail") {
        Some(v) => serde_json::from_value(v.clone()).map_err(|e| format!("extensions.mail: {e}"))?,
        None => MailEnv::default(),
    };

    let builder = match cfg.encryption {
        Encryption::Tls => AsyncSmtpTransport::<Tokio1Executor>::relay(&cfg.host),
        Encryption::Starttls => AsyncSmtpTransport::<Tokio1Executor>::starttls_relay(&cfg.host),
        Encryption::None => Ok(AsyncSmtpTransport::<Tokio1Executor>::builder_dangerous(&cfg.host)),
    }
    .map_err(|e| format!("extensions.mail.host: {e}"))?;

    let mut builder = builder
        .port(cfg.port)
        .timeout(Some(Duration::from_secs(cfg.timeout_seconds)));
    if !cfg.username.is_empty() {
        builder = builder.credentials(Credentials::new(cfg.username, cfg.password));
    }

    let from = Mailbox::new(
        Some(cfg.from_name),
        cfg.from_address.parse().map_err(|e| format!("extensions.mail.from_address: {e}"))?,
    );

    Ok(Mailer { transport: builder.build(), from })
}

// ===============================================================================
// Envío
// ===============================================================================

pub struct Email {
    pub subject: String,
    pub html: String,
    pub text: String,
}

pub async fn send(to_name: &str, to_address: &str, email: Email) -> Result<(), ForgeError> {
    let mailer = mailer()?;

    let to = Mailbox::new(
        Some(to_name.to_string()),
        to_address
            .parse()
            .map_err(|e| ForgeError::internal().caused_by(e).message("Invalid recipient email"))?,
    );

    let message = Message::builder()
        .from(mailer.from.clone())
        .to(to)
        .subject(&email.subject)
        .multipart(MultiPart::alternative_plain_html(email.text, email.html))
        .map_err(|e| ForgeError::internal().caused_by(e).message("Failed to build email"))?;

    mailer.transport.send(message).await.map_err(|e| {
        log::error(
            "Failed to send email",
            Some(json!({ "fn": "mailer::send", "error": e.to_string(), "subject": email.subject })),
        );
        ForgeError::internal().caused_by(e).message("Failed to send email")
    })?;
    Ok(())
}
