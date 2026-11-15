use std::time::Duration;

use ironforge::{ForgeError, ODModel, log};
use mongodb::{
    IndexModel,
    bson::{DateTime, doc, oid::ObjectId},
    options::{IndexOptions, ReturnDocument},
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio::sync::OnceCell;

/// Intentos permitidos por código de 6 dígitos (1 en 200.000 de adivinarlo).
pub const MAX_CODE_ATTEMPTS: u32 = 5;

// ===============================================================================
// Modelo
// ===============================================================================

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TokenType {
    /// Enlace para confirmar el email.
    VerifyEmail,
    /// Enlace para restablecer la contraseña (email).
    ResetPassword,
    /// Código de 6 dígitos para confirmar el teléfono (WhatsApp).
    VerifyPhone,
    /// Código de 6 dígitos para restablecer la contraseña (WhatsApp).
    /// Separado de `ResetPassword` para que nunca se valide con `consume_link`.
    ResetPasswordCode,
    /// Código de 6 dígitos para una segunda verificación (email o WhatsApp).
    SecondFactor,
}

/// Token de un solo uso. Solo se guarda el SHA-256: el valor en claro va
/// únicamente en el email. Al usarse se borra, y los vencidos los borra Mongo
/// con el índice TTL sobre `expires_at`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Token {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<ObjectId>,
    pub user_id: ObjectId,
    pub token_type: TokenType,
    pub token_hash: String,
    /// Información extra que necesite cada tipo de token.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
    /// Intentos de validar el código (solo códigos; los enlaces no lo usan).
    #[serde(default)]
    pub attempts: u32,
    pub expires_at: DateTime,
    pub created_at: DateTime,
}

impl ODModel for Token {
    fn coll_name() -> &'static str {
        "tokens"
    }

    fn get_id(&self) -> Option<ObjectId> {
        self.id
    }

    fn set_id(&mut self, id: ObjectId) {
        self.id = Some(id);
    }
}

impl Token {
    /// Crea un token para un enlace (32 bytes aleatorios en hex) y devuelve
    /// el valor en claro para ponerlo en el email. Reemplaza al anterior del
    /// mismo tipo para ese usuario.
    pub async fn issue_link(
        user_id: ObjectId,
        token_type: TokenType,
        data: Option<Value>,
        ttl: Duration,
    ) -> Result<String, ForgeError> {
        let mut bytes = [0u8; 32];
        random_fill(&mut bytes)?;
        let plain = to_hex(&bytes);
        Self::issue(user_id, token_type, &plain, data, ttl).await?;
        Ok(plain)
    }

    /// Crea un código numérico de 6 dígitos y lo devuelve en claro.
    /// Reemplaza al anterior del mismo tipo para ese usuario.
    pub async fn issue_code(
        user_id: ObjectId,
        token_type: TokenType,
        data: Option<Value>,
        ttl: Duration,
    ) -> Result<String, ForgeError> {
        let mut bytes = [0u8; 4];
        random_fill(&mut bytes)?;
        let plain = format!("{:06}", u32::from_le_bytes(bytes) % 1_000_000);
        Self::issue(user_id, token_type, &plain, data, ttl).await?;
        Ok(plain)
    }

    /// Valida y gasta un token de enlace: si existe y no venció, lo borra y lo devuelve.
    pub async fn consume_link(token_type: TokenType, plain: &str) -> Result<Self, ForgeError> {
        Self::consume(doc! {
            "token_type": token_type_bson(token_type)?,
            "token_hash": hash(plain),
            "expires_at": { "$gt": DateTime::now() },
        })
        .await
    }

    /// Valida y gasta un código de 6 dígitos del usuario.
    ///
    /// Se filtra por usuario porque 6 dígitos se repiten entre usuarios, y cada
    /// código admite como máximo `MAX_CODE_ATTEMPTS` intentos: el intento se cuenta
    /// (`$inc` atómico) antes de comparar, así ni con requests en paralelo se
    /// prueban más códigos que el límite. Agotados, hay que pedir uno nuevo.
    pub async fn consume_code(
        user_id: ObjectId,
        token_type: TokenType,
        plain: &str,
    ) -> Result<Self, ForgeError> {
        let coll = Self::coll()?;
        let token = coll
            .find_one_and_update(
                doc! {
                    "user_id": user_id,
                    "token_type": token_type_bson(token_type)?,
                    "expires_at": { "$gt": DateTime::now() },
                    "attempts": { "$lt": MAX_CODE_ATTEMPTS },
                },
                doc! { "$inc": { "attempts": 1 } },
            )
            .return_document(ReturnDocument::After)
            .await
            .map_err(|e| ForgeError::internal().caused_by(e).message("Failed to read token"))?
            .ok_or_else(|| ForgeError::not_found().message("Invalid or expired code"))?;

        if token.token_hash != hash(plain) {
            if token.attempts >= MAX_CODE_ATTEMPTS {
                return Err(ForgeError::too_many_requests().message("Too many attempts, request a new code"));
            }
            return Err(ForgeError::not_found().message("Invalid or expired code"));
        }

        // Si dos requests correctos llegan a la vez, solo el que lo borra lo gasta.
        let deleted = coll
            .delete_one(doc! { "_id": token.id })
            .await
            .map_err(|e| ForgeError::internal().caused_by(e).message("Failed to consume token"))?;
        if deleted.deleted_count == 0 {
            return Err(ForgeError::not_found().message("Invalid or expired code"));
        }
        Ok(token)
    }

    /// Campo de texto guardado en `data`, o `None` si no existe o no es texto.
    /// Ej: `token.data_field("email")`.
    pub fn data_field(&self, key: &str) -> Option<&str> {
        self.data.as_ref()?.get(key)?.as_str()
    }

    async fn issue(
        user_id: ObjectId,
        token_type: TokenType,
        plain: &str,
        data: Option<Value>,
        ttl: Duration,
    ) -> Result<(), ForgeError> {
        ensure_indexes().await?;

        Self::coll()?
            .delete_many(doc! { "user_id": user_id, "token_type": token_type_bson(token_type)? })
            .await
            .map_err(|e| {
                ForgeError::internal().caused_by(e).message("Failed to replace previous token")
            })?;

        let now = DateTime::now();
        let mut token = Self {
            id: None,
            user_id,
            token_type,
            token_hash: hash(plain),
            data,
            attempts: 0,
            expires_at: DateTime::from_millis(now.timestamp_millis() + ttl.as_millis() as i64),
            created_at: now,
        };
        token.create().await
    }

    async fn consume(filter: mongodb::bson::Document) -> Result<Self, ForgeError> {
        Self::coll()?
            .find_one_and_delete(filter)
            .await
            .map_err(|e| ForgeError::internal().caused_by(e).message("Failed to read token"))?
            .ok_or_else(|| ForgeError::not_found().message("Invalid or expired token"))
    }
}

// ===============================================================================
// Utilidades
// ===============================================================================

/// Crea los índices una vez por proceso:
/// - TTL en `expires_at`: Mongo borra los tokens vencidos.
/// - `token_hash`: búsqueda al consumir.
/// - `user_id + token_type`: reemplazo del token anterior.
async fn ensure_indexes() -> Result<(), ForgeError> {
    static DONE: OnceCell<()> = OnceCell::const_new();
    DONE.get_or_try_init(|| async {
        let indexes = vec![
            IndexModel::builder()
                .keys(doc! { "expires_at": 1 })
                .options(IndexOptions::builder().expire_after(Duration::ZERO).build())
                .build(),
            IndexModel::builder().keys(doc! { "token_hash": 1 }).build(),
            IndexModel::builder().keys(doc! { "user_id": 1, "token_type": 1 }).build(),
        ];
        Token::coll()?.create_indexes(indexes).await.map(|_| ()).map_err(|e| {
            log::error(
                "Failed to create token indexes",
                Some(json!({ "fn": "Token::ensure_indexes", "error": e.to_string() })),
            );
            ForgeError::internal().caused_by(e).message("Failed to create token indexes")
        })
    })
    .await
    .map(|_| ())
}

fn token_type_bson(t: TokenType) -> Result<mongodb::bson::Bson, ForgeError> {
    mongodb::bson::to_bson(&t)
        .map_err(|e| ForgeError::internal().caused_by(e).message("Invalid token type"))
}

fn hash(plain: &str) -> String {
    to_hex(&Sha256::digest(plain.as_bytes()))
}

fn random_fill(buf: &mut [u8]) -> Result<(), ForgeError> {
    getrandom::fill(buf)
        .map_err(|e| ForgeError::internal().message(format!("Failed to generate token: {e}")))
}

fn to_hex(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        out.push(HEX[(b >> 4) as usize] as char);
        out.push(HEX[(b & 0x0f) as usize] as char);
    }
    out
}
