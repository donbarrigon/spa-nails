//! Segundo factor con apps de autenticación (Google Authenticator, Authy, ...)
//! usando TOTP (RFC 6238): código de 6 dígitos que cambia cada 30 s, calculado
//! con el secreto del usuario y la hora. El servidor no guarda códigos, solo el
//! secreto y el último intervalo aceptado.
//!
//! El secreto se guarda cifrado con AES-256-GCM (clave derivada de `app.key`):
//! a diferencia de una contraseña no se puede hashear, porque hace falta el
//! valor original para calcular el código.

use aes_gcm::{
    Aes256Gcm, Nonce,
    aead::{Aead, KeyInit, Payload},
};
use ironforge::{ForgeError, ODModel, env};
use mongodb::bson::{doc, oid::ObjectId};
use sha2::{Digest, Sha256};
use totp_rs::{Builder, Secret, Totp};

use crate::app::shared::models::user::User;

/// Nombre que muestra la app de autenticación junto a la cuenta.
const ISSUER: &str = "MR nails";

/// Prefijo del formato guardado, por si algún día cambia el cifrado o la clave.
const CIPHER_VERSION: &str = "v1";
const NONCE_LEN: usize = 12;

/// Genera un secreto nuevo (20 bytes) y lo pone cifrado en el usuario, sin
/// guardarlo. Reinicia la confirmación: hasta validar un primer código con
/// `verify` no sirve para iniciar sesión.
pub fn generate_secret(user: &mut User) -> Result<(), ForgeError> {
    let secret = Secret::generate();
    user.totp_secret = Some(encrypt(user_id(user)?, secret.as_bytes())?);
    user.totp_confirmed_at = None;
    user.totp_last_step = None;
    Ok(())
}

/// Secreto en Base32, para escribirlo a mano en la app si no se puede escanear el QR.
pub fn secret(user: &User) -> Result<String, ForgeError> {
    Ok(decrypt_secret(user)?.to_base32())
}

/// URI `otpauth://totp/...` que va dentro del QR.
pub fn url(user: &User) -> Result<String, ForgeError> {
    totp(user)?
        .to_url()
        .map_err(|e| ForgeError::internal().message(format!("Failed to build authenticator URL: {e}")))
}

/// QR con la URI, como PNG en base64 (para `<img src="data:image/png;base64,...">`).
pub fn qr(user: &User) -> Result<String, ForgeError> {
    totp(user)?
        .to_qr_base64()
        .map_err(|e| ForgeError::internal().message(format!("Failed to build authenticator QR: {e}")))
}

/// Código vigente (el mismo que muestra la app en este momento).
pub fn code(user: &User) -> Result<String, ForgeError> {
    Ok(totp(user)?.generate_current().to_string())
}

/// Valida un código y lo gasta. Acepta el intervalo anterior y el siguiente
/// (±30 s) por desfase de reloj.
///
/// Un código no se acepta dos veces: el intervalo aceptado se guarda en
/// `totp_last_step` con un update condicionado a que sea mayor que el último,
/// así ni con requests en paralelo se usa el mismo código dos veces.
pub async fn verify(user: &mut User, code: &str) -> Result<(), ForgeError> {
    let invalid = || ForgeError::not_found().message("Invalid or expired code");

    let step = totp(user)?.check_current(code).ok_or_else(invalid)? as i64;
    let id = user_id(user)?;

    let res = User::coll()?
        .update_one(
            doc! {
                "_id": id,
                "$or": [
                    { "totp_last_step": null },
                    { "totp_last_step": { "$lt": step } },
                ],
            },
            doc! { "$set": { "totp_last_step": step } },
        )
        .await
        .map_err(|e| ForgeError::internal().caused_by(e).message("Failed to verify code"))?;
    if res.matched_count == 0 {
        return Err(invalid());
    }

    user.totp_last_step = Some(step);
    Ok(())
}

fn totp(user: &User) -> Result<Totp, ForgeError> {
    // SHA-1, 6 dígitos, 30 s y ±1 intervalo: lo que soportan todas las apps.
    Builder::new()
        .with_secret(decrypt_secret(user)?)
        .with_account_name(user.email.as_str())
        .with_issuer(Some(ISSUER))
        .build()
        .map_err(|e| ForgeError::internal().message(format!("Invalid authenticator config: {e}")))
}

fn decrypt_secret(user: &User) -> Result<Secret, ForgeError> {
    let stored = user
        .totp_secret
        .as_deref()
        .ok_or_else(|| ForgeError::unprocessable_entity().message("Authenticator app is not set up"))?;
    Ok(Secret::from(decrypt(user_id(user)?, stored)?))
}

fn user_id(user: &User) -> Result<ObjectId, ForgeError> {
    user.id
        .ok_or_else(|| ForgeError::internal().message("Authenticator app requires a saved user"))
}

// ===============================================================================
// Cifrado
// ===============================================================================
// Formato guardado: `v1:<hex(nonce de 12 bytes + secreto cifrado + tag de 16 bytes)>`.
// El id del usuario va como dato asociado (AAD): un secreto copiado al documento
// de otro usuario no se descifra.

/// Clave de 32 bytes derivada de `app.key`. El prefijo separa este uso de los
/// demás de la misma `app.key` (cookies, etc.).
fn cipher() -> Result<Aes256Gcm, ForgeError> {
    let mut hasher = Sha256::new();
    hasher.update(b"spa-nails:totp-secret:");
    hasher.update(env().app.key.as_bytes());
    Aes256Gcm::new_from_slice(&hasher.finalize())
        .map_err(|e| ForgeError::internal().message(format!("Invalid authenticator cipher key: {e}")))
}

fn encrypt(user_id: ObjectId, plain: &[u8]) -> Result<String, ForgeError> {
    let mut nonce = [0u8; NONCE_LEN];
    getrandom::fill(&mut nonce)
        .map_err(|e| ForgeError::internal().message(format!("Failed to generate nonce: {e}")))?;

    let aad = user_id.bytes();
    let encrypted = cipher()?
        .encrypt(&Nonce::from(nonce), Payload { msg: plain, aad: &aad })
        .map_err(|_| ForgeError::internal().message("Failed to encrypt authenticator secret"))?;

    let mut raw = nonce.to_vec();
    raw.extend_from_slice(&encrypted);
    Ok(format!("{CIPHER_VERSION}:{}", to_hex(&raw)))
}

fn decrypt(user_id: ObjectId, stored: &str) -> Result<Vec<u8>, ForgeError> {
    let invalid = || ForgeError::internal().message("Invalid authenticator secret");

    let hex = stored
        .strip_prefix(CIPHER_VERSION)
        .and_then(|rest| rest.strip_prefix(':'))
        .ok_or_else(invalid)?;
    let raw = from_hex(hex).ok_or_else(invalid)?;
    if raw.len() <= NONCE_LEN {
        return Err(invalid());
    }
    let (nonce, encrypted) = raw.split_at(NONCE_LEN);
    let nonce: [u8; NONCE_LEN] = nonce.try_into().map_err(|_| invalid())?;

    let aad = user_id.bytes();
    cipher()?
        .decrypt(&Nonce::from(nonce), Payload { msg: encrypted, aad: &aad })
        .map_err(|_| invalid())
}

fn to_hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn from_hex(hex: &str) -> Option<Vec<u8>> {
    if hex.len() % 2 != 0 {
        return None;
    }
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(hex.get(i..i + 2)?, 16).ok())
        .collect()
}
