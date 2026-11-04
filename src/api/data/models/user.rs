use chrono::{DateTime, Utc};
use ironforge::{ForgeError, db::mongo_model::ODModel};
use mongodb::bson::oid::ObjectId;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Option<ObjectId>,
    pub name: String,
    pub email: String,
    pub phone: String,
    pub password: String,
    pub email_verified_at: Option<DateTime<Utc>>,
    pub phone_verified_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
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

    fn before_create(&mut self) -> Result<(), ForgeError> {
        let now = Utc::now();
        self.created_at = now;
        self.updated_at = now;
        Ok(())
    }

    fn before_update(&mut self) -> Result<(), ForgeError> {
        self.updated_at = Utc::now();
        Ok(())
    }
}