//! Límite de intentos (ej. contraseñas incorrectas) por clave: cuenta, IP, etc.
//! Cada clave cuenta los intentos dentro de una ventana de tiempo; al llegar al
//! máximo se bloquea hasta que la ventana vence. Mongo borra las vencidas (TTL).

use std::time::Duration;

use ironforge::{ForgeError, ODModel, log};
use mongodb::{
    IndexModel,
    bson::{DateTime, doc, oid::ObjectId},
    options::IndexOptions,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use tokio::sync::OnceCell;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Throttle {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<ObjectId>,
    /// Qué se limita, ej. `password:account:<user_id>` o `password:ip:<ip>`.
    pub key: String,
    pub count: u32,
    /// Fin de la ventana: después de esto el contador vuelve a empezar.
    pub expires_at: DateTime,
}

impl ODModel for Throttle {
    fn coll_name() -> &'static str {
        "throttles"
    }

    fn get_id(&self) -> Option<ObjectId> {
        self.id
    }

    fn set_id(&mut self, id: ObjectId) {
        self.id = Some(id);
    }
}

/// Una clave con su máximo de intentos por ventana.
pub struct Limit {
    pub key: String,
    pub max: u32,
    pub window: Duration,
}

impl Limit {
    pub fn new(key: impl Into<String>, max: u32, window: Duration) -> Self {
        Self { key: key.into(), max, window }
    }
}

impl Throttle {
    /// Falla con 429 si alguna clave ya llegó a su máximo en la ventana vigente.
    pub async fn check(limits: &[Limit]) -> Result<(), ForgeError> {
        let keys: Vec<&str> = limits.iter().map(|l| l.key.as_str()).collect();
        let now = DateTime::now();
        let blocked = Self::find::<Self>(doc! { "key": { "$in": keys }, "expires_at": { "$gt": now } })?
            .get()
            .await?
            .into_iter()
            .filter(|t| limits.iter().any(|l| l.key == t.key && t.count >= l.max))
            .map(|t| t.expires_at.timestamp_millis())
            .max();

        match blocked {
            Some(until) => {
                let minutes = ((until - now.timestamp_millis()) as f64 / 60_000.0).ceil().max(1.0);
                Err(ForgeError::too_many_requests()
                    .message(format!("Too many attempts, try again in {minutes} minutes")))
            }
            None => Ok(()),
        }
    }

    /// Suma un intento a cada clave. Si la ventana venció, empieza una nueva.
    pub async fn hit(limits: &[Limit]) -> Result<(), ForgeError> {
        ensure_indexes().await?;
        for limit in limits {
            if !Self::increment(&limit.key).await? {
                Self::start_window(limit).await?;
            }
        }
        Ok(())
    }

    /// Borra el contador de una clave (ej. tras una contraseña correcta).
    /// Si falla solo se registra: no debe impedir la acción que lo llamó.
    pub async fn clear(key: &str) {
        let res = match Self::coll() {
            Ok(coll) => coll.delete_many(doc! { "key": key }).await.map(|_| ()).map_err(|e| e.to_string()),
            Err(e) => Err(e.to_string()),
        };
        if let Err(e) = res {
            log::error("Failed to clear throttle", Some(json!({ "fn": "Throttle::clear", "key": key, "error": e })));
        }
    }

    /// `+1` en la ventana vigente; `false` si no hay ventana vigente.
    async fn increment(key: &str) -> Result<bool, ForgeError> {
        let res = Self::coll()?
            .update_one(
                doc! { "key": key, "expires_at": { "$gt": DateTime::now() } },
                doc! { "$inc": { "count": 1 } },
            )
            .await
            .map_err(|e| ForgeError::internal().caused_by(e).message("Failed to update throttle"))?;
        Ok(res.matched_count > 0)
    }

    async fn start_window(limit: &Limit) -> Result<(), ForgeError> {
        let expires_at = DateTime::from_millis(DateTime::now().timestamp_millis() + limit.window.as_millis() as i64);
        let res = Self::coll()?
            .update_one(
                doc! { "key": &limit.key },
                doc! { "$set": { "count": 1, "expires_at": expires_at } },
            )
            .upsert(true)
            .await;
        match res {
            Ok(_) => Ok(()),
            // Dos requests crearon la misma clave a la vez (índice único): la otra
            // ya abrió la ventana, este intento se suma a esa.
            Err(e) if is_duplicate_key(&e) => Self::increment(&limit.key).await.map(|_| ()),
            Err(e) => Err(ForgeError::internal().caused_by(e).message("Failed to update throttle")),
        }
    }
}

fn is_duplicate_key(e: &mongodb::error::Error) -> bool {
    matches!(
        e.kind.as_ref(),
        mongodb::error::ErrorKind::Write(mongodb::error::WriteFailure::WriteError(w)) if w.code == 11000
    )
}

/// Crea los índices una vez por proceso:
/// - `key` único: un contador por clave.
/// - TTL en `expires_at`: Mongo borra las ventanas vencidas.
async fn ensure_indexes() -> Result<(), ForgeError> {
    static DONE: OnceCell<()> = OnceCell::const_new();
    DONE.get_or_try_init(|| async {
        let indexes = vec![
            IndexModel::builder()
                .keys(doc! { "key": 1 })
                .options(IndexOptions::builder().unique(true).build())
                .build(),
            IndexModel::builder()
                .keys(doc! { "expires_at": 1 })
                .options(IndexOptions::builder().expire_after(Duration::ZERO).build())
                .build(),
        ];
        Throttle::coll()?.create_indexes(indexes).await.map(|_| ()).map_err(|e| {
            log::error(
                "Failed to create throttle indexes",
                Some(json!({ "fn": "Throttle::ensure_indexes", "error": e.to_string() })),
            );
            ForgeError::internal().caused_by(e).message("Failed to create throttle indexes")
        })
    })
    .await
    .map(|_| ())
}
