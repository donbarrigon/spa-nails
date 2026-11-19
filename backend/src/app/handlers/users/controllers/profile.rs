use ironforge::{Context, ForgeError, ODModel, session};
use mongodb::bson::{doc, to_bson};
use serde_json::{Value, json};

use crate::app::{
    shared::{
        models::{history::{ActionType::Update, History}, user::User},
        resources::session_user::SessionUser,
    },
    handlers::users::validators::profile::{PreferencesValidator, UpdateProfileValidator},
};

// TODO: subir avatar y banner cuando ironforge reciba archivos (multipart).

/// `PUT /api/users/profile` — body `{ "nickname", "name", "birthdate", "document_type",
/// "document", "address", "city" }`. Los opcionales van como `""` (o `null` el
/// `document_type`) para borrarlos.
///
/// Exige sesión. Responde el usuario de la sesión actualizado.
pub async fn update(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<UpdateProfileValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    if req.nickname != user.nickname
        && User::exists(doc! { "nickname": &req.nickname, "_id": { "$ne": auth.user_id } }).await?
    {
        return Err(ForgeError::conflict().message("Nickname already exists"));
    }

    let old = json!({ "nickname": user.nickname, "profile": personal_data(&user) });
    let document_type = to_bson(&req.document_type)
        .map_err(|e| ForgeError::internal().caused_by(e).message("Invalid document type"))?;
    user.update_fields(doc! {
        "nickname": &req.nickname,
        "profile.name": &req.name,
        "profile.birthdate": req.birthdate(),
        "profile.document_type": document_type,
        "profile.document": non_empty(&req.document),
        "profile.address": non_empty(&req.address),
        "profile.city": non_empty(&req.city),
    })
    .await?;
    session()?.refresh_user(SessionUser::try_from(&user)?).await?;

    History::record(c, user.clone(), Some(old), Update, Some("User update profile")).await;

    c.response_ok(&SessionUser::try_from(&user)?)
}

/// `PUT /api/users/profile/preferences` — body `{ "theme": "light" | "dark" }`.
///
/// Exige sesión. Solo cambia las preferencias que llegan; las demás se
/// conservan. Responde el usuario de la sesión actualizado.
pub async fn update_preferences(c: &mut Context) -> Result<(), ForgeError> {
    let auth = c.auth::<SessionUser>().await?;
    let req = c.get_body::<PreferencesValidator>().await?;
    let mut user = User::get_by_id(auth.user_id).await?;

    let old = json!({ "preferences": user.profile.preferences });
    // Los usuarios anteriores a `preferences` lo tienen en `null`.
    let mut preferences = match &user.profile.preferences {
        Value::Object(map) => map.clone(),
        _ => Default::default(),
    };
    preferences.insert("theme".into(), json!(req.theme));

    let preferences = to_bson(&preferences)
        .map_err(|e| ForgeError::internal().caused_by(e).message("Invalid preferences"))?;
    user.update_fields(doc! { "profile.preferences": preferences }).await?;
    session()?.refresh_user(SessionUser::try_from(&user)?).await?;

    History::record(c, user.clone(), Some(old), Update, Some("User update preferences")).await;

    c.response_ok(&SessionUser::try_from(&user)?)
}

fn non_empty(value: &str) -> Option<&str> {
    (!value.is_empty()).then_some(value)
}

/// Datos que cambia [`update`], para el historial.
fn personal_data(user: &User) -> Value {
    let p = &user.profile;
    json!({
        "name": p.name,
        "birthdate": p.birthdate,
        "document_type": p.document_type,
        "document": p.document,
        "address": p.address,
        "city": p.city,
    })
}
