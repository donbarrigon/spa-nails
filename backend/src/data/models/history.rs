use ironforge::{Context, ODModel, log};
use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::data::resources::session_user::SessionUser;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActionType {
    Find,
    Create,
    Update,
    Delete,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct History {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<ObjectId>,
    pub action: ActionType,
    pub user_id: ObjectId,   // quién la hizo
    pub entity: String,      // colección afectada, ej. "users"
    pub entity_id: ObjectId, // documento afectado
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>, // datos antiguos que cambiaron
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>, // descripción del cambio
    pub created_at: DateTime,
}

impl ODModel for History {
    fn coll_name() -> &'static str {
        "history"
    }

    fn get_id(&self) -> Option<ObjectId> {
        self.id
    }

    fn set_id(&mut self, id: ObjectId) {
        self.id = Some(id);
    }
}

impl History {
    pub async fn record<T: ODModel>(
        c: &mut Context,
        model: T,
        data: Option<Value>,
        action: ActionType,
        description: Option<impl Into<String>>,
    ) {
        let auth = match c.auth::<SessionUser>().await {
            Ok(auth) => auth,
            Err(e) => {
                log::error(
                    "Failed to record history: no session",
                    Some(json!({ "fn": "History::record", "error": e.to_string(), "data": data })),
                );
                return;
            }
        };
        let Some(entity_id) = model.get_id() else {
            log::error(
                "Failed to record history: model without id",
                Some(json!({ "fn": "History::record", "error": "model without id", "data": data })),
            );
            return;
        };

        let mut history = Self {
            id: None,
            action,
            user_id: auth.user_id,
            entity: T::coll_name().to_string(),
            entity_id,
            data,
            description: description.map(Into::into),
            created_at: DateTime::now(),
        };
        if let Err(e) = history.create().await {
            log::error(
                "Failed to record history",
                Some(json!({ "fn": "History::record", "error": e.to_string(), "data": history })),
            );
        }
    }
}
