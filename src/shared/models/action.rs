use ironforge::{Auth, Context, ForgeError, db::mongo_model::ODModel};
use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActionType {
    Find,
    Create,
    Update,
    Delete,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Action {
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

impl ODModel for Action {
    fn coll_name() -> &'static str {
        "actions"
    }

    fn get_id(&self) -> Option<ObjectId> {
        self.id
    }

    fn set_id(&mut self, id: ObjectId) {
        self.id = Some(id);
    }
}

impl Action {
    pub async fn record<T: ODModel>(
        c: &mut Context,
        model: T,
        data: Option<Value>,
        action: ActionType,
        description: Option<impl Into<String>>,
    ) -> Result<(), ForgeError> {
        let auth = Auth::load(c)?;

        let mut action = Self {
            id: None,
            action,
            user_id: auth.user_id,
            entity: T::coll_name().to_string(),
            entity_id: model.get_id().unwrap(),
            data,
            description: description.map(Into::into),
            created_at: DateTime::now(),
        };
        action.create().await?;
        Ok(())
    }
}
