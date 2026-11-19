use std::sync::OnceLock;

use argon2::{
    Algorithm, Argon2, Params, Version,
    password_hash::{PasswordHasher, PasswordVerifier, phc::PasswordHash},
};
use chrono::NaiveTime;
use ironforge::{ForgeError, ODModel};
use mongodb::bson::{DateTime, doc, oid::ObjectId};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use serde_json::Value;
use tokio::sync::{OnceCell, Semaphore};

use crate::app::{
    handlers::users::validators::user::{GoogleRegisterValidator, UserRegisterValidator},
    shared::services::google::GoogleIdentity,
};

// ===============================================================================
// Modelo
// ===============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<ObjectId>,
    pub nickname: String,

    pub email: String,
    /// Formato internacional con `+` y solo dígitos, ej. `+573001234567`.
    pub phone: String,
    /// Email nuevo esperando confirmación; `email` no cambia hasta confirmarlo.
    #[serde(default)]
    pub pending_email: Option<String>,
    /// Teléfono nuevo esperando confirmación; `phone` no cambia hasta confirmarlo.
    #[serde(default)]
    pub pending_phone: Option<String>,
    pub password: String,
    #[serde(default)]
    pub roles: Vec<String>,
    #[serde(default)]
    pub permissions: Vec<String>,
    pub profile: Profile,
    /// Solo para empleados; `None` en clientes.
    pub employee: Option<Employee>,
    pub remember_token: Option<String>,
    pub email_verified_at: Option<DateTime>,
    pub phone_verified_at: Option<DateTime>,
    /// Método preferido del segundo factor al iniciar sesión; `None` = desactivado.
    #[serde(default)]
    pub two_factor: Option<TwoFactorMethod>,
    /// Secreto TOTP de la app de autenticación, cifrado con `app.key`
    /// (ver `services::totp`); `None` = sin configurar.
    #[serde(default)]
    pub totp_secret: Option<String>,
    /// Cuándo se confirmó la app de autenticación con un primer código. Hasta
    /// entonces el secreto no sirve para iniciar sesión.
    #[serde(default)]
    pub totp_confirmed_at: Option<DateTime>,
    /// Último intervalo de 30 s aceptado: el mismo código no se acepta dos veces.
    #[serde(default)]
    pub totp_last_step: Option<i64>,
    /// ID de la cuenta de Google vinculada (`sub` del ID token); `None` = sin
    /// login con Google. Único entre usuarios.
    #[serde(default)]
    pub google_sub: Option<String>,
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
    /// Preferencias libres del usuario como objeto JSON (`{ "clave": valor }`).
    /// Leer con [`Profile::preference`].
    #[serde(default)]
    pub preferences: Value,
}

impl Profile {
    pub const DEFAULT_AVATAR: &'static str = "public/img/profile/avatar.jpg";
    pub const DEFAULT_BANNER: &'static str = "public/img/profile/banner.jpg";

    /// Valor de la preferencia `key` convertido a `T`; `None` si no existe o
    /// no tiene la forma de `T`. Ej: `profile.preference::<bool>("dark_mode")`.
    pub fn preference<T: DeserializeOwned>(&self, key: &str) -> Option<T> {
        T::deserialize(self.preferences.get(key)?).ok()
    }
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

impl DocumentType {
    /// Como se guarda: `"CC"`, `"NIT"`...
    pub const fn code(self) -> &'static str {
        match self {
            Self::Cc => "CC",
            Self::Ce => "CE",
            Self::Ti => "TI",
            Self::Pp => "PP",
            Self::Ppt => "PPT",
            Self::Nit => "NIT",
        }
    }
}

/// Tema de la app elegido en las preferencias (`profile.preferences.theme`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Theme {
    Light,
    Dark,
}

/// De dónde sale el código del segundo factor. Se guarda como "email", "whatsapp" o "totp".
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum TwoFactorMethod {
    Email,
    Whatsapp,
    /// App de autenticación (Google Authenticator, Authy, ...).
    Totp,
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
        if Self::exists(doc! { "phone": &self.phone }).await? {
            return Err(ForgeError::conflict().message("Phone already exists"));
        }
        if let Some(sub) = &self.google_sub
            && Self::exists(doc! { "google_sub": sub }).await?
        {
            return Err(ForgeError::conflict().message("This Google account is already linked to another account"));
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
        Self::new_client(req.nickname, req.name, req.email, req.phone, req.password)
    }

    /// Registro con Google: el email sale del ID token (ya verificado por
    /// Google) y la cuenta queda vinculada. El teléfono se verifica aparte.
    pub fn fill_google_register(req: GoogleRegisterValidator, google: GoogleIdentity) -> Self {
        let mut user = Self::new_client(req.nickname, req.name, google.email, req.phone, req.password);
        user.email_verified_at = Some(user.created_at);
        user.google_sub = Some(google.sub);
        user
    }

    fn new_client(nickname: String, name: String, email: String, phone: String, password: String) -> Self {
        let now = DateTime::now();
        Self {
            id: None,
            nickname,
            profile: Profile {
                avatar: Profile::DEFAULT_AVATAR.to_string(),
                banner: Profile::DEFAULT_BANNER.to_string(),
                name,
                birthdate: None,
                document_type: None,
                document: None,
                address: None,
                city: None,
                preferences: Value::Object(Default::default()),
            },
            email,
            phone,
            pending_email: None,
            pending_phone: None,
            password, // en claro hasta `before_create`, que la hashea
            employee: None,
            remember_token: None,
            email_verified_at: None,
            phone_verified_at: None,
            two_factor: None,
            totp_secret: None,
            totp_confirmed_at: None,
            totp_last_step: None,
            google_sub: None,
            roles: Vec::new(),
            permissions: Vec::new(),
            created_at: now,
            updated_at: now,
            deleted_at: None,
        }
    }

    /// Si el método sirve como segundo factor: email o teléfono verificado, o
    /// app de autenticación confirmada.
    pub fn can_use_two_factor(&self, method: TwoFactorMethod) -> bool {
        match method {
            TwoFactorMethod::Email => self.email_verified_at.is_some(),
            TwoFactorMethod::Whatsapp => self.phone_verified_at.is_some(),
            TwoFactorMethod::Totp => self.totp_confirmed_at.is_some(),
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
        verify_limited(self.password.clone(), password).await
    }

    /// Para un usuario que no existe: verifica contra un hash falso para tardar
    /// lo mismo que `check_password`, así el tiempo de respuesta del login no
    /// revela si la cuenta existe. El hash se crea una vez por proceso.
    pub async fn check_password_dummy(password: String) -> Result<(), ForgeError> {
        static DUMMY: OnceCell<String> = OnceCell::const_new();
        let hash = DUMMY
            .get_or_try_init(|| async {
                let _permit = hash_permits().acquire().await.map_err(|e| {
                    ForgeError::internal().caused_by(e).message("Hash limiter closed")
                })?;
                tokio::task::spawn_blocking(|| hash_sync("dummy-password-for-constant-time"))
                    .await
                    .map_err(|e| ForgeError::internal().caused_by(e).message("Hash task failed"))?
            })
            .await?
            .clone();
        verify_limited(hash, password).await.map(|_| ())
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

/// Verifica en un hilo bloqueante, respetando el límite de hashes simultáneos.
async fn verify_limited(hash: String, password: String) -> Result<bool, ForgeError> {
    let _permit = hash_permits()
        .acquire()
        .await
        .map_err(|e| ForgeError::internal().caused_by(e).message("Hash limiter closed"))?;
    tokio::task::spawn_blocking(move || verify_sync(&hash, &password))
        .await
        .map_err(|e| ForgeError::internal().caused_by(e).message("Verify hash failed"))
}

fn verify_sync(hash: &str, password: &str) -> bool {
    let Ok(parsed) = PasswordHash::new(hash) else {
        return false;
    };
    Argon2::default()
        .verify_password(password.as_bytes(), &parsed)
        .is_ok()
}
