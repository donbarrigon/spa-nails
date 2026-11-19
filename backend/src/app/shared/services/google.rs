//! Inicio de sesión con Google: verifica el ID token (JWT RS256) que la app
//! obtiene con `google_sign_in`, con la config de `env.json` → `extensions.google`.
//!
//! No se llama a Google por cada login: se valida la firma con sus llaves
//! públicas (JWKS), que se guardan en memoria el tiempo que indica su
//! `Cache-Control`. Si llega un `kid` desconocido (Google rotó las llaves) se
//! vuelven a pedir, como mucho una vez por `MIN_REFRESH`.

use std::{
    sync::{Arc, OnceLock},
    time::{Duration, Instant},
};

use aws_lc_rs::signature::{RSA_PKCS1_2048_8192_SHA256, RsaPublicKeyComponents};
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use ironforge::{ForgeError, env, log};
use serde::Deserialize;
use serde_json::{Value, json};
use tokio::sync::Mutex;

// ===============================================================================
// Configuración: env.json → extensions.google
// ===============================================================================

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct GoogleEnv {
    /// Client IDs de OAuth (Google Cloud → Credenciales) aceptados como `aud`:
    /// el de Web y, si la app no usa `serverClientId`, los de Android e iOS.
    pub client_ids: Vec<String>,
    /// Llaves públicas con las que Google firma los ID tokens.
    pub jwks_url: String,
    pub timeout_seconds: u64,
}

impl Default for GoogleEnv {
    fn default() -> Self {
        Self {
            client_ids: Vec::new(),
            jwks_url: "https://www.googleapis.com/oauth2/v3/certs".into(),
            timeout_seconds: 10,
        }
    }
}

struct Google {
    http: reqwest::Client,
    jwks_url: String,
    client_ids: Vec<String>,
    keys: Mutex<Option<CachedKeys>>,
}

struct CachedKeys {
    keys: Arc<Vec<Jwk>>,
    fetched_at: Instant,
    expires_at: Instant,
}

/// Se arma una vez con `extensions.google` y se reutiliza.
fn google() -> Result<&'static Google, ForgeError> {
    static GOOGLE: OnceLock<Result<Google, String>> = OnceLock::new();
    GOOGLE
        .get_or_init(build_google)
        .as_ref()
        .map_err(|e| ForgeError::internal().message(format!("Google sign-in is not configured: {e}")))
}

fn build_google() -> Result<Google, String> {
    let cfg: GoogleEnv = match env().extensions.get("google") {
        Some(v) => serde_json::from_value(v.clone()).map_err(|e| format!("extensions.google: {e}"))?,
        None => GoogleEnv::default(),
    };
    let client_ids: Vec<String> = cfg.client_ids.into_iter().filter(|id| !id.trim().is_empty()).collect();
    if client_ids.is_empty() {
        return Err("extensions.google.client_ids is empty".into());
    }

    // Igual que en WhatsApp: cubre usar el cliente antes de que arranque el servidor.
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();

    let http = reqwest::Client::builder()
        .timeout(Duration::from_secs(cfg.timeout_seconds))
        .build()
        .map_err(|e| format!("http client: {e}"))?;

    Ok(Google { http, jwks_url: cfg.jwks_url, client_ids, keys: Mutex::new(None) })
}

// ===============================================================================
// Verificación
// ===============================================================================

/// Quién es el usuario según Google.
#[derive(Debug, Clone)]
pub struct GoogleIdentity {
    /// ID de la cuenta de Google: no cambia nunca (el email sí puede cambiar).
    pub sub: String,
    /// En minúsculas y verificado por Google.
    pub email: String,
    pub name: Option<String>,
}

/// Llave pública RSA del JWKS de Google.
#[derive(Debug, Clone, Deserialize)]
pub struct Jwk {
    pub kid: String,
    pub kty: String,
    /// Módulo en base64url.
    pub n: String,
    /// Exponente en base64url.
    pub e: String,
}

#[derive(Deserialize)]
struct Jwks {
    keys: Vec<Jwk>,
}

/// Por qué no se aceptó un ID token. Solo va al log: al cliente siempre se le
/// responde el mismo mensaje.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum IdTokenError {
    /// Firmado con una llave que no está en el JWKS (puede que Google la haya rotado).
    UnknownKey,
    Invalid(&'static str),
}

/// Holgura para `exp`, por diferencias de reloj con Google.
const CLOCK_SKEW_SECS: i64 = 60;
const ISSUERS: [&str; 2] = ["accounts.google.com", "https://accounts.google.com"];

/// Verifica el ID token y devuelve la identidad de Google. Cualquier fallo
/// responde `401` con el mismo mensaje.
pub async fn verify_id_token(token: &str) -> Result<GoogleIdentity, ForgeError> {
    let g = google()?;
    let now = chrono::Utc::now().timestamp();

    let cached = signing_keys(g, false).await?;
    let result = match verify_with_keys(token, &cached, &g.client_ids, now) {
        Err(IdTokenError::UnknownKey) => {
            let refreshed = signing_keys(g, true).await?;
            verify_with_keys(token, &refreshed, &g.client_ids, now)
        }
        other => other,
    };

    result.map_err(|e| {
        log::info("Rejected Google ID token", Some(json!({ "fn": "google::verify_id_token", "reason": format!("{e:?}") })));
        ForgeError::unauthorized().message("Google sign-in failed, try again")
    })
}

/// Verificación pura (sin red ni reloj): firma con `keys`, emisor, audiencia
/// en `client_ids`, vencimiento contra `now` (segundos Unix) y email verificado.
pub fn verify_with_keys(
    token: &str,
    keys: &[Jwk],
    client_ids: &[String],
    now: i64,
) -> Result<GoogleIdentity, IdTokenError> {
    use IdTokenError::*;

    let mut parts = token.split('.');
    let (Some(header_b64), Some(payload_b64), Some(signature_b64), None) =
        (parts.next(), parts.next(), parts.next(), parts.next())
    else {
        return Err(Invalid("malformed token"));
    };

    let header: Value = decode_json(header_b64).ok_or(Invalid("malformed header"))?;
    if header["alg"] != "RS256" {
        return Err(Invalid("unsupported alg"));
    }
    let kid = header["kid"].as_str().ok_or(Invalid("missing kid"))?;
    let key = keys.iter().find(|k| k.kid == kid && k.kty == "RSA").ok_or(UnknownKey)?;

    let n = URL_SAFE_NO_PAD.decode(&key.n).map_err(|_| Invalid("malformed key"))?;
    let e = URL_SAFE_NO_PAD.decode(&key.e).map_err(|_| Invalid("malformed key"))?;
    let signature = URL_SAFE_NO_PAD.decode(signature_b64).map_err(|_| Invalid("malformed signature"))?;
    let signed = &token[..header_b64.len() + 1 + payload_b64.len()];
    RsaPublicKeyComponents { n: &n, e: &e }
        .verify(&RSA_PKCS1_2048_8192_SHA256, signed.as_bytes(), &signature)
        .map_err(|_| Invalid("bad signature"))?;

    // Desde aquí el contenido es de Google.
    let claims: Value = decode_json(payload_b64).ok_or(Invalid("malformed payload"))?;

    if !ISSUERS.iter().any(|iss| claims["iss"] == *iss) {
        return Err(Invalid("wrong issuer"));
    }
    let aud_ok = match &claims["aud"] {
        Value::String(aud) => client_ids.contains(aud),
        Value::Array(auds) => auds.iter().any(|a| a.as_str().is_some_and(|a| client_ids.iter().any(|c| c == a))),
        _ => false,
    };
    if !aud_ok {
        return Err(Invalid("wrong audience"));
    }
    let exp = claims["exp"].as_i64().ok_or(Invalid("missing exp"))?;
    if exp + CLOCK_SKEW_SECS < now {
        return Err(Invalid("expired"));
    }

    let sub = claims["sub"].as_str().filter(|s| !s.is_empty()).ok_or(Invalid("missing sub"))?;
    let email = claims["email"].as_str().filter(|s| !s.is_empty()).ok_or(Invalid("missing email"))?;
    // Google lo manda como bool; en tokens viejos venía como texto.
    let verified = claims["email_verified"] == true || claims["email_verified"] == "true";
    if !verified {
        return Err(Invalid("email not verified"));
    }

    Ok(GoogleIdentity {
        sub: sub.to_string(),
        email: email.trim().to_lowercase(),
        name: claims["name"].as_str().map(|n| n.trim().to_string()).filter(|n| !n.is_empty()),
    })
}

fn decode_json(part: &str) -> Option<Value> {
    let bytes = URL_SAFE_NO_PAD.decode(part).ok()?;
    serde_json::from_slice(&bytes).ok()
}

// ===============================================================================
// Llaves (JWKS)
// ===============================================================================

/// Nunca se piden las llaves más de una vez por este tiempo, aunque lleguen
/// tokens con `kid` desconocido (ej. falsos): así no se puede usar el login
/// para hacer que el servidor bombardee a Google.
const MIN_REFRESH: Duration = Duration::from_secs(60);
/// Si Google no manda `max-age`.
const DEFAULT_MAX_AGE: Duration = Duration::from_secs(60 * 60);
const MAX_MAX_AGE: Duration = Duration::from_secs(24 * 60 * 60);

/// Llaves en caché, o pedidas de nuevo si vencieron o si `force` (kid desconocido).
async fn signing_keys(g: &Google, force: bool) -> Result<Arc<Vec<Jwk>>, ForgeError> {
    let mut cache = g.keys.lock().await;
    let now = Instant::now();
    if let Some(c) = cache.as_ref() {
        let fresh = now < c.expires_at;
        let recent = now.duration_since(c.fetched_at) < MIN_REFRESH;
        if (fresh && !force) || recent {
            return Ok(c.keys.clone());
        }
    }

    let (keys, max_age) = fetch_keys(g).await?;
    let keys = Arc::new(keys);
    *cache = Some(CachedKeys { keys: keys.clone(), fetched_at: now, expires_at: now + max_age });
    Ok(keys)
}

async fn fetch_keys(g: &Google) -> Result<(Vec<Jwk>, Duration), ForgeError> {
    let fail = |error: String| {
        log::error("Failed to fetch Google keys", Some(json!({ "fn": "google::fetch_keys", "error": error })));
        ForgeError::internal().message("Google sign-in is temporarily unavailable, try again")
    };

    let res = g.http.get(&g.jwks_url).send().await.map_err(|e| fail(e.to_string()))?;
    if !res.status().is_success() {
        return Err(fail(format!("status {}", res.status().as_u16())));
    }
    let max_age = res
        .headers()
        .get(reqwest::header::CACHE_CONTROL)
        .and_then(|v| v.to_str().ok())
        .and_then(parse_max_age)
        .unwrap_or(DEFAULT_MAX_AGE)
        .min(MAX_MAX_AGE);
    let jwks: Jwks = res.json().await.map_err(|e| fail(e.to_string()))?;
    Ok((jwks.keys, max_age))
}

/// `public, max-age=19832, must-revalidate, no-transform` → 19832 s.
fn parse_max_age(cache_control: &str) -> Option<Duration> {
    cache_control
        .split(',')
        .find_map(|d| d.trim().strip_prefix("max-age="))
        .and_then(|s| s.parse().ok())
        .map(Duration::from_secs)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_max_age_lee_la_directiva() {
        assert_eq!(
            parse_max_age("public, max-age=19832, must-revalidate, no-transform"),
            Some(Duration::from_secs(19832))
        );
        assert_eq!(parse_max_age("no-cache"), None);
    }
}
