use std::sync::OnceLock;

use aws_lc_rs::{
    rand::SystemRandom,
    rsa::{KeyPair, KeySize},
    signature::{KeyPair as _, RSA_PKCS1_SHA256},
};
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use serde_json::{Value, json};

use crate::app::handler::services::google::{IdTokenError, Jwk, verify_with_keys};

const CLIENT_ID: &str = "web.apps.googleusercontent.com";
const KID: &str = "kid-1";
const NOW: i64 = 1_800_000_000;

/// Generar una llave RSA es lento: una sola para todos los tests.
fn key() -> &'static KeyPair {
    static KEY: OnceLock<KeyPair> = OnceLock::new();
    KEY.get_or_init(|| KeyPair::generate(KeySize::Rsa2048).unwrap())
}

fn jwks() -> Vec<Jwk> {
    let public = key().public_key();
    vec![Jwk {
        kid: KID.into(),
        kty: "RSA".into(),
        n: URL_SAFE_NO_PAD.encode(public.modulus().big_endian_without_leading_zero()),
        e: URL_SAFE_NO_PAD.encode(public.exponent().big_endian_without_leading_zero()),
    }]
}

fn claims() -> Value {
    json!({
        "iss": "https://accounts.google.com",
        "aud": CLIENT_ID,
        "sub": "1234567890",
        "email": "Ana@Gmail.com",
        "email_verified": true,
        "name": "Ana Pérez",
        "iat": NOW - 10,
        "exp": NOW + 3600,
    })
}

fn sign(header: Value, claims: Value) -> String {
    let b64 = |v: &Value| URL_SAFE_NO_PAD.encode(serde_json::to_vec(v).unwrap());
    let signed = format!("{}.{}", b64(&header), b64(&claims));
    let mut signature = vec![0; key().public_modulus_len()];
    key().sign(&RSA_PKCS1_SHA256, &SystemRandom::new(), signed.as_bytes(), &mut signature).unwrap();
    format!("{signed}.{}", URL_SAFE_NO_PAD.encode(signature))
}

fn token(claims: Value) -> String {
    sign(json!({ "alg": "RS256", "kid": KID, "typ": "JWT" }), claims)
}

fn verify(token: &str) -> Result<crate::app::handler::services::google::GoogleIdentity, IdTokenError> {
    verify_with_keys(token, &jwks(), &[CLIENT_ID.to_string()], NOW)
}

#[test]
fn acepta_un_token_valido_y_normaliza_el_email() {
    let identity = verify(&token(claims())).unwrap();
    assert_eq!(identity.sub, "1234567890");
    assert_eq!(identity.email, "ana@gmail.com");
    assert_eq!(identity.name.as_deref(), Some("Ana Pérez"));
}

#[test]
fn acepta_el_emisor_sin_https_y_email_verified_como_texto() {
    let mut c = claims();
    c["iss"] = json!("accounts.google.com");
    c["email_verified"] = json!("true");
    assert!(verify(&token(c)).is_ok());
}

#[test]
fn rechaza_una_firma_alterada() {
    let mut c = claims();
    let good = token(c.clone());
    // Mismo header y firma, payload con otro `sub`.
    c["sub"] = json!("otra-persona");
    let forged_payload = URL_SAFE_NO_PAD.encode(serde_json::to_vec(&c).unwrap());
    let parts: Vec<&str> = good.split('.').collect();
    let forged = format!("{}.{}.{}", parts[0], forged_payload, parts[2]);
    assert_eq!(verify(&forged).unwrap_err(), IdTokenError::Invalid("bad signature"));
}

#[test]
fn rechaza_otro_alg() {
    let t = sign(json!({ "alg": "none", "kid": KID }), claims());
    assert_eq!(verify(&t).unwrap_err(), IdTokenError::Invalid("unsupported alg"));
}

#[test]
fn kid_desconocido_pide_refrescar_las_llaves() {
    let t = sign(json!({ "alg": "RS256", "kid": "otra" }), claims());
    assert_eq!(verify(&t).unwrap_err(), IdTokenError::UnknownKey);
}

#[test]
fn rechaza_otra_audiencia() {
    let mut c = claims();
    c["aud"] = json!("de-otra-app.apps.googleusercontent.com");
    assert_eq!(verify(&token(c)).unwrap_err(), IdTokenError::Invalid("wrong audience"));
}

#[test]
fn rechaza_otro_emisor() {
    let mut c = claims();
    c["iss"] = json!("https://evil.example.com");
    assert_eq!(verify(&token(c)).unwrap_err(), IdTokenError::Invalid("wrong issuer"));
}

#[test]
fn rechaza_un_token_vencido_pero_tolera_el_desfase_de_reloj() {
    let mut c = claims();
    c["exp"] = json!(NOW - 30);
    assert!(verify(&token(c.clone())).is_ok());

    c["exp"] = json!(NOW - 120);
    assert_eq!(verify(&token(c)).unwrap_err(), IdTokenError::Invalid("expired"));
}

#[test]
fn rechaza_email_sin_verificar() {
    let mut c = claims();
    c["email_verified"] = json!(false);
    assert_eq!(verify(&token(c)).unwrap_err(), IdTokenError::Invalid("email not verified"));
}

#[test]
fn rechaza_tokens_mal_formados() {
    assert_eq!(verify("a.b").unwrap_err(), IdTokenError::Invalid("malformed token"));
    assert_eq!(verify("a.b.c.d").unwrap_err(), IdTokenError::Invalid("malformed token"));
    assert_eq!(verify("@@.b.c").unwrap_err(), IdTokenError::Invalid("malformed header"));
}
