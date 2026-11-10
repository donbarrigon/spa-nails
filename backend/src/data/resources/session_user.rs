use ironforge::{Authenticatable, ForgeError};
use mongodb::bson::{DateTime, oid::ObjectId};
use serde::{Deserialize, Serialize};

use crate::data::models::user::User;

/// Copia del usuario que vive en la sesión (RAM y documento de sesión en Mongo).
/// Todo el `User` menos las credenciales: `password` y `remember_token`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionUser {
    pub id: ObjectId,
    pub nickname: String,
    pub email: String,
    pub phone_code: String,
    pub phone: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email_verified_at: Option<DateTime>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub phone_verified_at: Option<DateTime>,
    pub roles: Vec<String>,
    pub permissions: Vec<String>,
    pub created_at: DateTime,
    pub updated_at: DateTime,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub deleted_at: Option<DateTime>,
}

/// Falla si el usuario no está guardado (sin `id`): solo se inicia sesión con usuarios de la base.
impl TryFrom<&User> for SessionUser {
    type Error = ForgeError;

    fn try_from(user: &User) -> Result<Self, Self::Error> {
        let id = user.id.ok_or_else(|| {
            ForgeError::internal().message("Cannot create a session for an unsaved user")
        })?;
        Ok(Self {
            id,
            nickname: user.nickname.clone(),
            email: user.email.clone(),
            phone_code: user.phone_code.clone(),
            phone: user.phone.clone(),
            roles: user.roles.clone(),
            permissions: user.permissions.clone(),
            email_verified_at: user.email_verified_at,
            phone_verified_at: user.phone_verified_at,
            created_at: user.created_at,
            updated_at: user.updated_at,
            deleted_at: user.deleted_at,
        })
    }
}

impl Authenticatable for SessionUser {
    fn auth_id(&self) -> ObjectId {
        self.id
    }

    fn roles(&self) -> &[String] {
        &self.roles
    }

    fn permissions(&self) -> &[String] {
        &self.permissions
    }
}
