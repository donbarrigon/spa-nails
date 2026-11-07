use std::sync::OnceLock;

use argon2::{
    Algorithm, Argon2, Params, Version,
    password_hash::{PasswordHasher, PasswordVerifier, phc::PasswordHash},
};
use ironforge::{ForgeError, ODModel};
use mongodb::bson::{DateTime, doc, oid::ObjectId};
use serde::{Deserialize, Serialize};
use tokio::sync::Semaphore;

use crate::api::handler::validators::user::UserRegisterValidator;

// ===============================================================================
// Modelo
// ===============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Option<ObjectId>,
    pub nickname: String,
    pub email: String,
    pub phone: String,
    pub password: String,
    pub remember_token: Option<String>,
    pub email_verified_at: Option<DateTime>,
    pub phone_verified_at: Option<DateTime>,
    pub created_at: DateTime,
    pub updated_at: DateTime,
    pub deleted_at: Option<DateTime>,
}

impl ODModel for User {
    fn coll_name() -> &'static str {
        "users"
    }

    fn get_id(&self) -> Option<ObjectId> {
        self.id
    }

    fn set_id(&mut self, id: ObjectId) {
        self.id = Some(id);
    }

    async fn before_create(&mut self) -> Result<(), ForgeError> {
        if Self::exists(doc! { "email": &self.email }).await? {
            return Err(ForgeError::conflict().message("Email already exists"));
        }
        if Self::exists(doc! { "phone": &self.phone }).await? {
            return Err(ForgeError::conflict().message("Phone already exists"));
        }

        self.hash_password().await?;

        Ok(())
    }

    async fn before_update(&mut self) -> Result<(), ForgeError> {
        self.updated_at = DateTime::now();
        Ok(())
    }
}

impl User {
    pub fn fill_register(req: UserRegisterValidator) -> Self {
        let now = DateTime::now();
        Self {
            id: None,
            nickname: req.nickname,
            email: req.email,
            phone: req.phone,
            password: req.password, // en claro hasta `before_create`, que la hashea
            remember_token: None,
            email_verified_at: None,
            phone_verified_at: None,
            created_at: now,
            updated_at: now,
            deleted_at: None,
        }
    }

    // == Contraseñas =============================================

    pub async fn hash_password(&mut self) -> Result<(), ForgeError> {
        let _permit = hash_permits().acquire().await.map_err(|e| {
            ForgeError::internal()
                .caused_by(e)
                .message(format!("Hash limiter closed"))
        })?;
        let plain = self.password.clone();
        self.password = tokio::task::spawn_blocking(move || hash_sync(&plain))
            .await
            .map_err(|e| {
                ForgeError::internal()
                    .caused_by(e)
                    .message(format!("Hash task failed"))
            })??;
        Ok(())
    }

    pub async fn check_password(&self, password: String) -> Result<bool, ForgeError> {
        let _permit = hash_permits().acquire().await.map_err(|e| {
            ForgeError::internal()
                .caused_by(e)
                .message(format!("Hash limiter closed"))
        })?;
        let hash = self.password.clone();
        tokio::task::spawn_blocking(move || verify_sync(&hash, &password))
            .await
            .map_err(|e| {
                ForgeError::internal()
                    .caused_by(e)
                    .message(format!("Verify hash failed"))
            })
    }

    /// `true` si el hash guardado usa un algoritmo o parámetros más débiles
    /// que los actuales. Se llama tras un login correcto: si da `true`, se
    /// vuelve a hashear la contraseña.
    pub fn needs_rehash(&self) -> bool {
        // Formato PHC: $argon2id$v=19$m=65536,t=3,p=1$<salt>$<hash>
        let mut parts = self.password.split('$');
        let (Some(""), Some("argon2id"), Some("v=19"), Some(params)) =
            (parts.next(), parts.next(), parts.next(), parts.next())
        else {
            return true;
        };

        let (mut m, mut t, mut p) = (0u32, 0u32, 0u32);
        for kv in params.split(',') {
            match kv.split_once('=') {
                Some(("m", v)) => m = v.parse().unwrap_or(0),
                Some(("t", v)) => t = v.parse().unwrap_or(0),
                Some(("p", v)) => p = v.parse().unwrap_or(0),
                _ => {}
            }
        }
        m < ARGON_M_COST || t < ARGON_T_COST || p < ARGON_P_COST
    }
}

// ===============================================================================
// Parámetros de Argon2id
// ===============================================================================
// Pensados para un VPS de 4 vCores / 8 GB.
const ARGON_M_COST: u32 = 65_536; // memoria en KiB (64 MiB)
const ARGON_T_COST: u32 = 3; // iteraciones
const ARGON_P_COST: u32 = 1; // paralelismo

/// Máximo de hashes/verificaciones corriendo a la vez. Cada uno ocupa
/// `ARGON_M_COST` de RAM, así que el tope de memoria es 4 x 64 MiB = 256 MiB.
const MAX_CONCURRENT_HASHES: usize = 4;

fn hash_permits() -> &'static Semaphore {
    static S: OnceLock<Semaphore> = OnceLock::new();
    S.get_or_init(|| Semaphore::new(MAX_CONCURRENT_HASHES))
}

fn argon2() -> Result<Argon2<'static>, ForgeError> {
    let params = Params::new(ARGON_M_COST, ARGON_T_COST, ARGON_P_COST, None).map_err(|e| {
        ForgeError::internal()
            .caused_by(e)
            .message(format!("Invalid hash params"))
    })?;
    Ok(Argon2::new(Algorithm::Argon2id, Version::V0x13, params))
}

/// Hash síncrono (CPU pesado). Usar `User::hash_password` desde código async.
fn hash_sync(password: &str) -> Result<String, ForgeError> {
    argon2()?
        .hash_password(password.as_bytes())
        .map(|hash| hash.to_string())
        .map_err(|e| {
            ForgeError::internal()
                .caused_by(e)
                .message(format!("Failed to hash password, try again"))
        })
}

fn verify_sync(hash: &str, password: &str) -> bool {
    let Ok(parsed) = PasswordHash::new(hash) else {
        return false;
    };
    Argon2::default()
        .verify_password(password.as_bytes(), &parsed)
        .is_ok()
}
