use ironforge::{Context, ForgeError};

use crate::{api::handler::validators::user::UserRegisterValidator, shared::models::user::User};

pub async fn register(c: &mut Context) -> Result<(), ForgeError> {
    let req = c.get_body::<UserRegisterValidator>().await?;

    let mut user = User::fill_register(req);

    user.create(c).await?;

    Ok(())
}
