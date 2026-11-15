use std::sync::OnceLock;

use argon2::{
    Algorithm, Argon2, Params, Version,
    password_hash::{PasswordHasher, PasswordVerifier, phc::PasswordHash},
};
use chrono::NaiveTime;
use ironforge::{ForgeError, ODModel};
use mongodb::bson::{DateTime, doc, oid::ObjectId};
use serde::{Deserialize, Serialize};
use tokio::sync::Semaphore;

use crate::app::handler::validators::user::UserRegisterValidator;

// ===============================================================================
// Modelo
// ===============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<ObjectId>,
    pub nickname: String,
    pub profile: Profile,
    pub email: String,
    pub phone_code: String,
    pub phone: String,
    pub password: String,
    #[serde(default)]
    pub roles: Vec<String>,
    #[serde(default)]
    pub permissions: Vec<String>,
    /// Solo para empleados; `None` en clientes.
    pub employee: Option<Employee>,
    pub remember_token: Option<String>,
    pub email_verified_at: Option<DateTime>,
    pub phone_verified_at: Option<DateTime>,
    pub created_at: DateTime,
    pub updated_at: DateTime,
    pub deleted_at: Option<DateTime>,
}

/// Datos personales del usuario.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Profile {
    /// Ruta relativa a la imagen.
    pub avatar: String,
    /// Imagen de fondo detrás del avatar (ruta relativa).
    pub banner: String,
    /// Nombre real.
    pub name: String,
    pub birthdate: Option<DateTime>,
    pub document_type: Option<DocumentType>,
    pub document: Option<String>,
    pub address: Option<String>,
    pub city: Option<String>,
}

impl Profile {
    pub const DEFAULT_AVATAR: &'static str = "public/img/profile/avatar.jpg";
    pub const DEFAULT_BANNER: &'static str = "public/img/profile/banner.jpg";
}

/// Se guarda en la base como string: "CC", "CE", "TI", "PP", "PPT", "NIT".
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum DocumentType {
    /// Cédula de ciudadanía
    Cc,
    /// Cédula de extranjería
    Ce,
    /// Tarjeta de identidad
    Ti,
    /// Pasaporte
    Pp,
    /// Permiso por protección temporal
    Ppt,
    /// Número de identificación tributaria
    Nit,
}

/// Datos laborales, solo para empleados.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Employee {
    pub eps: String,
    /// Fondo de pensión.
    pub pension: String,
    /// Se guarda como "HH:MM:SS"; al ser texto con ceros a la izquierda.
    pub start_time: NaiveTime,
    pub end_time: NaiveTime,
    pub work_days: Vec<WorkDay>,
}

/// Se guarda en la base como string: "monday", "tuesday", ...
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum WorkDay {
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
    Sunday,
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
        if Self::exists(doc! { "nickname": &self.nickname }).await? {
            return Err(ForgeError::conflict().message("Nickname already exists"));
        }
        if Self::exists(doc! { "email": &self.email }).await? {
            return Err(ForgeError::conflict().message("Email already exists"));
        }
        if Self::exists(doc! { "phone_code": &self.phone_code, "phone": &self.phone }).await? {
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
            profile: Profile {
                avatar: Profile::DEFAULT_AVATAR.to_string(),
                banner: Profile::DEFAULT_BANNER.to_string(),
                name: req.name,
                birthdate: None,
                document_type: None,
                document: None,
                address: None,
                city: None,
            },
            email: req.email,
            phone_code: req.phone_code,
            phone: req.phone,
            password: req.password, // en claro hasta `before_create`, que la hashea
            employee: None,
            remember_token: None,
            email_verified_at: None,
            phone_verified_at: None,
            roles: Vec::new(),
            permissions: Vec::new(),
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
